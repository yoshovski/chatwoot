import { nextTick, watch } from 'vue';
import { emitter } from 'shared/helpers/mitt';
import { ON_AGENT_MESSAGE_RECEIVED } from 'widget/constants/widgetBusEvents';
import { IFrameHelper } from 'widget/helpers/utils';
import { MESSAGE_TYPE } from 'widget/helpers/constants';
import { requestAttention } from 'widget/api/attention';
import { attentionState } from 'widget/helpers/attentionState';
import {
  attentionCandidate,
  createAttentionTimer,
  publicMessages,
  replyKey,
} from 'widget/helpers/attentionPolicy';

// The server only needs to know the visit is alive, not every keystroke.
const ACTIVITY_INTERVAL_MS = 30000;
const ACTIVITY_EVENTS = ['pointerdown', 'keydown', 'input', 'scroll'];
const storageKey = () =>
  `cw-attention:${window.chatwootWebChannel?.websiteToken}:dismissed`;

const acknowledge = (kind, grant) =>
  requestAttention(kind, { eventId: grant.event_id }).catch(() => {});

// The visitor chose a suggestion: the offer did its job, nothing is snoozed.
export const clearAttentionOffer = () => {
  attentionState.offer = null;
};

// "I'm all set" or closing the offer stops automatic re-engagement for this visit.
export const dismissAttention = () => {
  if (attentionState.offer)
    acknowledge('dismissed', attentionState.offer.grant);
  attentionState.offer = null;
  attentionState.snoozed = true;
  requestAttention('snooze').catch(() => {});
};

// Closing a reply preview only keeps that reply from coming back.
export const dismissPreview = key => {
  if (attentionState.offer) dismissAttention();
  attentionState.previewDismissedKey = key;
  try {
    localStorage.setItem(storageKey(), key);
  } catch {
    // Embedded storage can be unavailable; the preview is then dismissed for this page view.
  }
};

export const startWidgetAttention = ({ store, router }) => {
  let lastActivity = 0;
  let seenObserver;
  const soundedReplies = new Set();
  try {
    attentionState.previewDismissedKey = localStorage.getItem(storageKey());
  } catch {
    // Optional local cache.
  }

  const messages = () => store.getters['conversation/getConversation'];
  const route = () => router.currentRoute.value.name;
  const isWidgetOpen = () =>
    store.getters['appConfig/getIsWidgetOpen'] || !IFrameHelper.isIFrame();
  const isOpen = () => isWidgetOpen() && route() === 'messages';
  // The closed-chat preview counts as closed: the chat itself is not on screen.
  const isPreviewCard = () => route() === 'unread-messages';
  const isVisible = () => !document.hidden && attentionState.hostVisible;
  const isBlocked = () =>
    !isVisible() ||
    !navigator.onLine ||
    attentionState.draft ||
    attentionState.composing ||
    attentionState.hostFormActive ||
    attentionState.snoozed ||
    store.getters['conversation/getIsAgentTyping'] ||
    store.getters['conversationAttributes/getConversationParams'].status !==
      'pending' ||
    (isWidgetOpen() && !isOpen() && !isPreviewCard());

  const timer = createAttentionTimer({
    claim: candidate =>
      requestAttention(candidate.kind, { messageId: candidate.messageId }),
    discard: grant => acknowledge('expired', grant),
    present: (candidate, grant) => {
      if (candidate.kind === 'question') {
        IFrameHelper.sendMessage({ event: 'highlightLauncher' });
      } else {
        attentionState.offer = {
          ...candidate,
          grant,
          text: grant.text,
          suggestions: grant.suggestions?.length
            ? grant.suggestions
            : candidate.suggestions,
        };
        if (!isOpen() && !isPreviewCard() && IFrameHelper.isIFrame()) {
          router
            .replace({ name: 'unread-messages' })
            .then(() => IFrameHelper.sendMessage({ event: 'setUnreadMode' }));
        }
      }
      acknowledge('presented', grant);
    },
  });

  const activity = () => {
    timer.activity();
    if (!isVisible() || Date.now() - lastActivity < ACTIVITY_INTERVAL_MS) {
      return;
    }
    lastActivity = Date.now();
    requestAttention('activity').catch(() => {});
  };

  // A reply is read when its last bubble is actually on screen, not when the route opens.
  const observeSeen = async () => {
    seenObserver?.disconnect();
    if (!isOpen() || !isVisible()) return;
    await nextTick();
    const last = publicMessages(messages()).at(-1);
    const element = last && document.getElementById(`cwmsg-${last.id}`);
    if (!element || !isOpen() || !isVisible()) return;
    seenObserver = new IntersectionObserver(
      entries => {
        if (!entries.some(entry => entry.isIntersecting)) return;
        store.dispatch('conversation/setUserLastSeen');
        seenObserver.disconnect();
      },
      { root: document.querySelector('.conversation--container') }
    );
    seenObserver.observe(element);
  };

  const refresh = () => {
    let candidate = attentionCandidate(messages());
    // A waiting question only nudges the closed launcher: the preview card already shows it and the
    // open chat has it on screen.
    if (candidate?.kind === 'question' && (isPreviewCard() || isOpen()))
      candidate = null;
    if (attentionState.offer && attentionState.offer.key !== candidate?.key) {
      attentionState.offer = null;
    }
    const latest = publicMessages(messages()).at(-1);
    const dismissed =
      latest && attentionState.previewDismissedKey === replyKey(latest);
    timer.update(candidate, isBlocked() || dismissed);
    observeSeen();
  };

  // One sound per logical reply, only when the chat is not in front of the visitor. The server
  // grants it to one tab; a sound that can't play now is dropped, never replayed later.
  const canSound = () =>
    !(isOpen() && isVisible()) &&
    !attentionState.muted &&
    attentionState.audioReady;
  const onMessage = async message => {
    if (message?.message_type !== MESSAGE_TYPE.OUTGOING) return;
    if (message.additional_attributes?.captain_initiated || message.campaign_id)
      return;
    const key = replyKey(message);
    if (soundedReplies.has(key)) return;
    soundedReplies.add(key);
    if (!canSound()) return;
    try {
      const grant = await requestAttention('sound', { messageId: message.id });
      if (!grant) return;
      if (!canSound()) {
        acknowledge('expired', grant);
        return;
      }
      IFrameHelper.sendMessage({ event: 'playAudio', replyKey: key });
      acknowledge('presented', grant);
    } catch {
      // A missed sound stays missed.
    }
  };

  const onHostEvent = event => {
    if (!IFrameHelper.isAValidEvent(event)) return;
    const data = IFrameHelper.getMessage(event);
    if (data.event !== 'attention-host-state') return;
    attentionState.hostVisible = data.visible;
    attentionState.hostFormActive = data.formActive;
    attentionState.muted = data.muted;
    attentionState.audioReady = data.audioReady;
  };
  const onVisibility = () => {
    activity();
    refresh();
  };

  watch(
    () => [
      messages(),
      store.getters['conversation/getIsAgentTyping'],
      store.getters['conversationAttributes/getConversationParams'].status,
      store.getters['appConfig/getIsWidgetOpen'],
      route(),
      attentionState.draft,
      attentionState.composing,
      attentionState.hostVisible,
      attentionState.hostFormActive,
      attentionState.snoozed,
    ],
    refresh,
    { deep: true }
  );
  ACTIVITY_EVENTS.forEach(event =>
    document.addEventListener(event, activity, { passive: true, capture: true })
  );
  window.addEventListener('message', onHostEvent);
  window.addEventListener('online', onVisibility);
  window.addEventListener('offline', onVisibility);
  document.addEventListener('visibilitychange', onVisibility);
  emitter.on(ON_AGENT_MESSAGE_RECEIVED, onMessage);
  activity();
  refresh();
};

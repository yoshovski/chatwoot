<script setup>
import { computed, onMounted, onBeforeUnmount, ref } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { emitter } from 'shared/helpers/mitt';
import {
  ON_CAMPAIGN_MESSAGE_CLICK,
  ON_UNREAD_MESSAGE_CLICK,
} from 'widget/constants/widgetBusEvents';
import { IFrameHelper } from 'widget/helpers/utils';
import { getExtraSpaceToScroll } from 'widget/helpers/IframeEventHelper';
import { attentionState } from 'widget/helpers/attentionState';
import { dismissPreview } from 'widget/composables/useWidgetAttention';
import { previewSender } from 'widget/helpers/notificationPreview';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import AttentionOffer from './AttentionOffer.vue';
import PreviewChoices from './PreviewChoices.vue';

// One card beside the launcher for the latest reply or opener, never a transcript.
const props = defineProps({ messages: { type: Array, default: () => [] } });
const emit = defineEmits(['close']);
const store = useStore();
const router = useRouter();
const { t } = useI18n();
const { getPlainText } = useMessageFormatter();
const root = ref(null);
const sending = ref(false);
const message = computed(() => props.messages.at(-1) || {});
const sender = computed(() =>
  previewSender(
    message.value.sender,
    window.chatwootWebChannel,
    t('UNREAD_VIEW.BOT')
  )
);
const excerpt = computed(() => getPlainText(message.value.content || ''));
const choices = computed(() =>
  (message.value.suggestedResponses || []).slice(0, 3)
);
const muteLabel = computed(() =>
  attentionState.muted ? t('ATTENTION.UNMUTE') : t('ATTENTION.MUTE')
);
let observer;

const open = () => {
  if (message.value.campaignId) {
    emitter.emit(ON_CAMPAIGN_MESSAGE_CLICK, {
      campaignId: message.value.campaignId,
    });
  } else {
    emitter.emit(ON_UNREAD_MESSAGE_CLICK);
  }
};
const choose = async choice => {
  if (sending.value) return;
  sending.value = true;
  if (message.value.campaignId) {
    emitter.emit(ON_CAMPAIGN_MESSAGE_CLICK, {
      campaignId: message.value.campaignId,
      selectedResponse: choice,
    });
  } else {
    open();
    await router.replace({ name: 'messages' });
    await store.dispatch('message/update', {
      messageId: message.value.choiceMessageId,
      submittedValues: [choice],
    });
  }
  sending.value = false;
};
const dismiss = () => {
  dismissPreview(
    message.value.previewKey || `campaign:${message.value.campaignId}`
  );
  emit('close');
};
const toggleMute = () => {
  attentionState.muted = !attentionState.muted;
  IFrameHelper.sendMessage({
    event: 'setAudioMuted',
    muted: attentionState.muted,
  });
};
onMounted(() => {
  observer = new ResizeObserver(() =>
    IFrameHelper.sendMessage({
      event: 'updateIframeHeight',
      isFixedHeight: true,
      extraHeight: getExtraSpaceToScroll(),
    })
  );
  observer.observe(root.value);
});
onBeforeUnmount(() => observer?.disconnect());
</script>

<template>
  <div ref="root" class="w-full p-6" data-notification-preview>
    <section
      class="group relative animate-fade-in-up overflow-hidden rounded-[1.25rem] border border-solid border-n-weak/60 bg-n-solid-1 text-n-slate-12 shadow-[0_0.5rem_1.5rem_-0.5rem_rgba(15,23,42,0.22),0_0.0625rem_0.1875rem_rgba(15,23,42,0.08)]"
    >
      <header class="flex h-11 items-center gap-2 pe-2 ps-5 pt-1">
        <Avatar
          :src="sender.avatarUrl"
          :name="sender.name"
          :size="20"
          rounded-full
        />
        <span class="min-w-0 flex-1 truncate text-xs text-n-slate-11">
          {{ sender.name }}
        </span>
        <div
          class="flex items-center opacity-0 transition-opacity group-focus-within:opacity-100 group-hover:opacity-100 [@media(hover:none)]:opacity-100"
        >
          <button
            type="button"
            class="flex size-8 items-center justify-center rounded-full text-n-slate-10 hover:bg-n-alpha-2 hover:text-n-slate-12"
            :aria-label="muteLabel"
            :aria-pressed="attentionState.muted"
            @click="toggleMute"
          >
            <i
              :class="
                attentionState.muted ? 'i-lucide-volume-x' : 'i-lucide-volume-2'
              "
              class="size-4"
            />
          </button>
          <button
            type="button"
            class="flex size-8 items-center justify-center rounded-full text-n-slate-10 hover:bg-n-alpha-2 hover:text-n-slate-12"
            :aria-label="$t('UNREAD_VIEW.CLOSE_MESSAGES_BUTTON')"
            @click="dismiss"
          >
            <i class="i-lucide-x size-4" />
          </button>
        </div>
      </header>
      <AttentionOffer v-if="attentionState.offer" variant="card" />
      <template v-else>
        <button
          class="block w-full px-5 pb-4 pt-1 text-start text-[0.9375rem] leading-6 text-n-slate-12"
          type="button"
          @click="open"
        >
          <span class="line-clamp-4">
            {{ excerpt || $t('ATTENTION.NEW_REPLY') }}
          </span>
        </button>
        <PreviewChoices
          v-if="choices.length"
          :choices="choices"
          :disabled="sending"
          @choose="choose"
        />
      </template>
    </section>
  </div>
</template>

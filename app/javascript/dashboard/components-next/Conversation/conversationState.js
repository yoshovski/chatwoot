// The four states an owner reads in the conversation list, built from fields the
// conversation payload already carries (status, assignee, the AI's ownership).
import { useI18n } from 'vue-i18n';
import { readSummary } from 'dashboard/components-next/captain/aiSummary/aiSummary';

export const CONVERSATION_STATE = {
  NEEDS_YOU: 'needs_you',
  AI_HANDLING: 'ai_handling',
  WAITING: 'waiting',
  SOLVED: 'solved',
};

// State → colours (the kit's StatusPill tones).
export const CONVERSATION_STATE_META = {
  needs_you: {
    pill: 'bg-n-amber-3 text-n-amber-11',
    dot: 'bg-n-amber-9',
  },
  ai_handling: {
    pill: 'bg-n-blue-3 text-n-blue-11',
    dot: 'bg-n-blue-9',
  },
  waiting: {
    pill: 'bg-n-alpha-2 text-n-slate-11',
    dot: 'bg-n-slate-9',
  },
  solved: {
    pill: 'bg-n-teal-3 text-n-teal-11',
    dot: 'bg-n-teal-9',
  },
};

// State → its name in the UI.
export const useConversationStateLabel = () => {
  const { t } = useI18n();
  return state =>
    ({
      needs_you: t('CHAT_LIST.STATE.NEEDS_YOU'),
      ai_handling: t('CHAT_LIST.STATE.AI_HANDLING'),
      waiting: t('CHAT_LIST.STATE.WAITING'),
      solved: t('CHAT_LIST.STATE.SOLVED'),
    })[state];
};

const AI_ASSIGNEE_TYPES = ['AgentBot', 'Captain::Assistant'];
const NEEDS_HUMAN_LABEL = 'needs-human';
const OUTGOING = 1;

const lastPublicMessage = conversation => {
  const fromStore = (conversation.messages || []).filter(
    message => message.message_type !== 2 && !message.private
  );
  return fromStore.at(-1) || conversation.last_non_activity_message;
};

export const conversationState = conversation => {
  const { status } = conversation;
  if (status === 'resolved') return CONVERSATION_STATE.SOLVED;
  if (status === 'snoozed') return CONVERSATION_STATE.WAITING;
  if (status === 'pending') return CONVERSATION_STATE.AI_HANDLING;

  // Open: the AI handed over, or a person owns it and the customer spoke last.
  const handedOff =
    conversation.labels?.includes(NEEDS_HUMAN_LABEL) ||
    !!conversation.captain_waiting ||
    readSummary(conversation)?.status === 'handed_off';
  const last = lastPublicMessage(conversation);
  const lastIsOurs = last?.message_type === OUTGOING;

  if (
    !handedOff &&
    AI_ASSIGNEE_TYPES.includes(conversation.meta?.assignee_type)
  ) {
    return CONVERSATION_STATE.AI_HANDLING;
  }
  return lastIsOurs ? CONVERSATION_STATE.WAITING : CONVERSATION_STATE.NEEDS_YOU;
};

// The AI agent's stored conversation summary (Captain::Conversation::Summary), read from the conversation payload.
export const SUMMARY_KEY = 'captain_summary';

import { useI18n } from 'vue-i18n';

// Status → dot colour.
export const SUMMARY_STATUS = {
  handed_off: 'bg-n-amber-9',
  lead: 'bg-n-blue-9',
  action: 'bg-n-teal-9',
  resolved: 'bg-n-slate-8',
};

// Status → the dot's accessible name.
export const useSummaryStatusLabel = () => {
  const { t } = useI18n();
  return status =>
    ({
      handed_off: t('CONVERSATION.AI_SUMMARY.STATUS.NEEDS_REPLY'),
      lead: t('CONVERSATION.AI_SUMMARY.STATUS.LEAD'),
      action: t('CONVERSATION.AI_SUMMARY.STATUS.ACTION'),
      resolved: t('CONVERSATION.AI_SUMMARY.STATUS.RESOLVED'),
    })[status];
};

export const readSummary = conversation => {
  const summary = conversation?.additional_attributes?.[SUMMARY_KEY];
  return summary && SUMMARY_STATUS[summary.status] ? summary : null;
};

// The one sentence to read first: what the customer wants, or why the AI handed over.
export const summaryHeadline = summary =>
  summary.wants || summary.reason || summary.lead?.summary || '';

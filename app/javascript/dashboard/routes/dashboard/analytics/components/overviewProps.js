// The props every Overview layout takes from OverviewTab.
export const overviewProps = {
  // { key: { label, value, change, changeTone, points, icon, tone, raw } }
  metrics: { type: Object, required: true },
  // [{ label, ai, team }] for the chart; rawDays keeps the ISO dates.
  days: { type: Array, default: () => [] },
  rawDays: { type: Array, default: () => [] },
  topics: { type: Array, default: () => [] },
  // [{ id, name, conversations, solved, firstReply }]
  team: { type: Array, default: () => [] },
  period: { type: Number, required: true },
  isLoading: { type: Boolean, default: false },
  hasError: { type: Boolean, default: false },
};

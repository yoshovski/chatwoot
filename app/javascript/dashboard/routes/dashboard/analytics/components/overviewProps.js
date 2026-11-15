// The props every Overview layout takes from OverviewTab.
export const overviewProps = {
  // { key: { label, value, change, changeTone, points, icon, tone, raw } }
  metrics: { type: Object, required: true },
  // [{ date, ai, team }] from the Home activity.
  rawDays: { type: Array, default: () => [] },
  topics: { type: Array, default: () => [] },
  // [{ id, name, conversations, solved, firstReply }]
  team: { type: Array, default: () => [] },
  period: { type: Number, required: true },
  isLoading: { type: Boolean, default: false },
  hasError: { type: Boolean, default: false },
};

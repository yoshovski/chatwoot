// Readiness and attention facts for the AI agent Overview. Pure, so the unknown-status rules are tested on their own.
//
// Knowledge, testing and the attention list come from `faq_stats`; when that request failed they are unknown,
// not incomplete: the checklist must not regress and the attention list must not claim an all-clear.

export const STEP_STATES = { DONE: 'done', TODO: 'todo', UNKNOWN: 'unknown' };

const fromFlag = flag => (flag ? STEP_STATES.DONE : STEP_STATES.TODO);
const fromStats = (stats, isDone) =>
  stats ? fromFlag(isDone(stats)) : STEP_STATES.UNKNOWN;

export const handoffIsSet = (config = {}) =>
  Boolean(
    config.handoff_when_online ||
      config.handoff_fallback_team_id ||
      config.handoff_fallback_agent_id ||
      config.handoff_rules?.length
  );

// `faqStats` is null while unknown (loading or failed); `channelsKnown` is false until the AI agent's channels loaded.
export const readinessStates = ({
  faqStats,
  config,
  channelCount,
  channelsKnown,
}) => ({
  knowledge: fromStats(faqStats, s => s.documents > 0 || s.approved > 0),
  handoff: fromFlag(handoffIsSet(config)),
  tested: fromStats(faqStats, s => Boolean(s.tested)),
  channel: channelsKnown ? fromFlag(channelCount > 0) : STEP_STATES.UNKNOWN,
});

// Show the checklist only when a known step is still open. Unknown steps never count as done or as open.
export const readinessSummary = states => {
  const values = Object.values(states);
  return {
    completed: values.filter(state => state === STEP_STATES.DONE).length,
    total: values.length,
    hasOpenStep: values.includes(STEP_STATES.TODO),
    hasUnknownStep: values.includes(STEP_STATES.UNKNOWN),
    nextOpenKey: Object.keys(states).find(
      key => states[key] === STEP_STATES.TODO
    ),
  };
};

const ATTENTION_COUNTS = [
  ['failedSources', 'failed_sources'],
  ['unansweredQuestions', 'unanswered_questions'],
  ['pausedActions', 'paused_actions'],
];

// [{ key, count }] for each attention fact above zero; null when the stats are unknown.
export const attentionCounts = faqStats =>
  faqStats
    ? ATTENTION_COUNTS.map(([key, field]) => ({
        key,
        count: faqStats[field] || 0,
      })).filter(item => item.count > 0)
    : null;

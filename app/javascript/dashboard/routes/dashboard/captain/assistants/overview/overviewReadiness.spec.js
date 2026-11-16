import {
  STEP_STATES,
  attentionCounts,
  readinessStates,
  readinessSummary,
} from './overviewReadiness';

const READY_STATS = {
  documents: 2,
  approved: 0,
  tested: true,
  failed_sources: 0,
  unanswered_questions: 0,
  paused_actions: 0,
};
const READY_CONFIG = { handoff_when_online: 'transfer' };

describe('readinessStates', () => {
  it('marks every step done for a ready AI agent', () => {
    const states = readinessStates({
      faqStats: READY_STATS,
      config: READY_CONFIG,
      channelCount: 1,
      channelsKnown: true,
    });

    expect(Object.values(states)).toEqual(Array(4).fill(STEP_STATES.DONE));
  });

  it('keeps knowledge and testing unknown when the stats failed to load', () => {
    const states = readinessStates({
      faqStats: null,
      config: READY_CONFIG,
      channelCount: 1,
      channelsKnown: true,
    });

    expect(states).toEqual({
      knowledge: STEP_STATES.UNKNOWN,
      handoff: STEP_STATES.DONE,
      tested: STEP_STATES.UNKNOWN,
      channel: STEP_STATES.DONE,
    });
  });

  it('keeps the channel unknown until the channel list loaded', () => {
    const states = readinessStates({
      faqStats: READY_STATS,
      config: READY_CONFIG,
      channelCount: 0,
      channelsKnown: false,
    });

    expect(states.channel).toBe(STEP_STATES.UNKNOWN);
  });

  it('counts approved FAQs as knowledge and marks open steps', () => {
    const states = readinessStates({
      faqStats: { ...READY_STATS, documents: 0, approved: 3, tested: false },
      config: {},
      channelCount: 0,
      channelsKnown: true,
    });

    expect(states).toEqual({
      knowledge: STEP_STATES.DONE,
      handoff: STEP_STATES.TODO,
      tested: STEP_STATES.TODO,
      channel: STEP_STATES.TODO,
    });
  });
});

describe('readinessSummary', () => {
  it('does not reopen setup when only unknown steps remain', () => {
    const summary = readinessSummary({
      knowledge: STEP_STATES.UNKNOWN,
      handoff: STEP_STATES.DONE,
      tested: STEP_STATES.UNKNOWN,
      channel: STEP_STATES.DONE,
    });

    expect(summary).toEqual({
      completed: 2,
      total: 4,
      hasOpenStep: false,
      hasUnknownStep: true,
      nextOpenKey: undefined,
    });
  });

  it('points at the first known open step', () => {
    const summary = readinessSummary({
      knowledge: STEP_STATES.UNKNOWN,
      handoff: STEP_STATES.TODO,
      tested: STEP_STATES.UNKNOWN,
      channel: STEP_STATES.TODO,
    });

    expect(summary.hasOpenStep).toBe(true);
    expect(summary.nextOpenKey).toBe('handoff');
  });
});

describe('attentionCounts', () => {
  it('is unknown, not all clear, without stats', () => {
    expect(attentionCounts(null)).toBeNull();
  });

  it('is empty when nothing needs attention', () => {
    expect(attentionCounts(READY_STATS)).toEqual([]);
  });

  it('lists each attention fact above zero', () => {
    expect(
      attentionCounts({
        ...READY_STATS,
        failed_sources: 1,
        paused_actions: 2,
      })
    ).toEqual([
      { key: 'failedSources', count: 1 },
      { key: 'pausedActions', count: 2 },
    ]);
  });
});

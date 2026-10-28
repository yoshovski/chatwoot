import { buildSetupProgress, SETUP_STEPS } from './homeSetup';

describe('buildSetupProgress', () => {
  it('lists the first three open steps in order', () => {
    const progress = buildSetupProgress({ ai_agent: true, knowledge: true });

    expect(progress.doneCount).toBe(2);
    expect(progress.total).toBe(SETUP_STEPS.length);
    expect(progress.openSteps.map(step => step.key)).toEqual([
      'agent_inbox',
      'chat_widget',
      'mailbox',
    ]);
    expect(progress.isComplete).toBe(false);
  });

  it('leaves skipped steps out and counts them as settled', () => {
    const setup = { ai_agent: true, knowledge: true, agent_inbox: true };
    const progress = buildSetupProgress(setup, [
      'chat_widget',
      'mailbox',
      'teammate',
    ]);

    expect(progress.doneCount).toBe(3);
    expect(progress.openSteps).toEqual([]);
    expect(progress.isComplete).toBe(true);
  });

  it('treats a missing summary as nothing done', () => {
    const progress = buildSetupProgress(undefined);

    expect(progress.doneCount).toBe(0);
    expect(progress.openSteps).toHaveLength(3);
  });
});

import { buildSetupProgress, SETUP_STEPS } from './homeSetup';

describe('buildSetupProgress', () => {
  it('keeps every step in order with its state', () => {
    const progress = buildSetupProgress({ ai_agent: true, knowledge: true }, [
      'mailbox',
    ]);

    expect(progress.steps.map(step => step.key)).toEqual(
      SETUP_STEPS.map(step => step.key)
    );
    expect(progress.steps.filter(step => step.done).map(s => s.key)).toEqual([
      'ai_agent',
      'knowledge',
    ]);
    expect(progress.steps.find(step => step.key === 'mailbox').skipped).toBe(
      true
    );
    expect(progress.doneCount).toBe(2);
    expect(progress.isComplete).toBe(false);
  });

  it('is complete when every step is done or skipped', () => {
    const setup = { ai_agent: true, knowledge: true, agent_inbox: true };
    const progress = buildSetupProgress(setup, [
      'chat_widget',
      'mailbox',
      'teammate',
    ]);

    expect(progress.doneCount).toBe(3);
    expect(progress.isComplete).toBe(true);
  });

  it('treats a missing summary as nothing done', () => {
    const progress = buildSetupProgress(undefined);

    expect(progress.doneCount).toBe(0);
    expect(progress.steps.every(step => !step.done)).toBe(true);
  });
});

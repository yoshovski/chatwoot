import {
  buildSetupProgress,
  firstOpenGuidedStep,
  GUIDED_STEPS,
  SETUP_STEPS,
} from './homeSetup';

describe('buildSetupProgress', () => {
  it('keeps every step in order with its state', () => {
    const progress = buildSetupProgress({ ai_agent: true, knowledge: true }, [
      'mailbox',
    ]);

    expect(progress.steps.map(step => step.key)).toEqual(
      SETUP_STEPS.map(step => step.key)
    );
    expect(progress.steps.filter(step => step.done).map(s => s.key)).toEqual([
      'knowledge',
    ]);
    expect(progress.steps.find(step => step.key === 'mailbox').skipped).toBe(
      true
    );
    expect(progress.doneCount).toBe(1);
    expect(progress.isComplete).toBe(false);
  });

  it('is complete when every step is done or skipped', () => {
    const setup = { knowledge: true, agent_inbox: true };
    const progress = buildSetupProgress(
      setup,
      ['chat_widget', 'mailbox', 'teammate'],
      ['test_agent']
    );

    expect(progress.doneCount).toBe(3);
    expect(progress.isComplete).toBe(true);
  });

  it('counts finished steps as done, even after they were skipped', () => {
    const progress = buildSetupProgress({}, ['test_agent'], ['test_agent']);
    const step = progress.steps.find(item => item.key === 'test_agent');

    expect(step).toMatchObject({ done: true, skipped: false });
  });

  it('treats a missing summary as nothing done', () => {
    const progress = buildSetupProgress(undefined);

    expect(progress.doneCount).toBe(0);
    expect(progress.steps.every(step => !step.done)).toBe(true);
  });
});

describe('firstOpenGuidedStep', () => {
  it('opens the first guided step that is still open', () => {
    const progress = buildSetupProgress({ knowledge: true }, ['test_agent']);

    expect(firstOpenGuidedStep(progress)).toBe('agent_inbox');
  });

  it('starts over when every guided step is settled', () => {
    const progress = buildSetupProgress(
      { knowledge: true, agent_inbox: true, chat_widget: true },
      [],
      ['test_agent']
    );

    expect(firstOpenGuidedStep(progress)).toBe(GUIDED_STEPS[0]);
  });
});

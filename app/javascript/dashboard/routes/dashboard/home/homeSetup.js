// Setup steps in the order a new workspace should do them. `guided` steps open the guided setup at that step;
// `navigationPath` steps open a Captain page for the first AI agent; the rest are plain routes. The website step
// creates the AI agent, so the server's `ai_agent` flag is not a step of its own here.
export const SETUP_STEPS = [
  { key: 'knowledge', guided: true },
  { key: 'test_agent', guided: true },
  { key: 'agent_inbox', guided: true },
  { key: 'chat_widget', guided: true },
  { key: 'mailbox', route: 'settings_inbox_new' },
  { key: 'teammate', route: 'agent_list' },
];

export const GUIDED_STEPS = SETUP_STEPS.filter(step => step.guided).map(
  step => step.key
);

// uiSettings keys. `finished` holds steps the server can't see, like testing the agent.
export const SKIPPED_SETTING = 'home_setup_skipped';
export const FINISHED_SETTING = 'home_setup_finished';
export const GUIDED_SHOWN_SETTING = 'guided_setup_shown';

export const buildSetupProgress = (setup = {}, skipped = [], finished = []) => {
  const steps = SETUP_STEPS.map(step => {
    const done = !!setup?.[step.key] || finished.includes(step.key);
    return { ...step, done, skipped: !done && skipped.includes(step.key) };
  });
  const settled = steps.filter(step => step.done || step.skipped).length;

  return {
    steps,
    doneCount: steps.filter(step => step.done).length,
    total: steps.length,
    isComplete: settled === steps.length,
  };
};

// The guided step to open: the first one that is neither done nor skipped, else the first one.
export const firstOpenGuidedStep = progress =>
  progress.steps.find(step => step.guided && !step.done && !step.skipped)
    ?.key || GUIDED_STEPS[0];

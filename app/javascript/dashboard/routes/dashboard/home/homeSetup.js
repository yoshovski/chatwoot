// Setup steps in the order a new workspace should do them. `navigationPath` steps open a Captain page for the
// first AI agent; the rest are plain routes.
export const SETUP_STEPS = [
  { key: 'ai_agent', navigationPath: 'captain_assistants_overview_index' },
  { key: 'knowledge', navigationPath: 'captain_assistants_documents_index' },
  { key: 'agent_inbox', navigationPath: 'captain_assistants_inboxes_index' },
  { key: 'chat_widget', route: 'settings_inbox_list' },
  { key: 'mailbox', route: 'settings_inbox_new' },
  { key: 'teammate', route: 'agent_list' },
];

export const buildSetupProgress = (setup = {}, skipped = []) => {
  const steps = SETUP_STEPS.map(step => ({
    ...step,
    done: !!setup[step.key],
    skipped: skipped.includes(step.key),
  }));
  const settled = steps.filter(step => step.done || step.skipped).length;

  return {
    steps,
    doneCount: steps.filter(step => step.done).length,
    total: steps.length,
    isComplete: settled === steps.length,
  };
};

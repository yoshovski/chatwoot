import { GUIDED_STEPS } from '../homeSetup';

// The setup never waits: every step has a primary action and "Skip for now", whatever the import or the AI agent is
// doing at that moment.

export const nextStep = key =>
  GUIDED_STEPS[GUIDED_STEPS.indexOf(key) + 1] || null;

// What the primary button does on `key`: start the website import, turn the agent on, move on, or finish.
export const primaryAction = (
  key,
  { websiteStarted = false, liveReady = false, isLive = false } = {}
) => {
  if (key === 'knowledge' && !websiteStarted) return 'start_website';
  if (key === 'agent_inbox' && liveReady && !isLive) return 'turn_on';
  return nextStep(key) ? 'next' : 'finish';
};

import { GUIDED_STEPS } from '../homeSetup';
import { nextStep, primaryAction } from './stepRules';

// Every state a step can be in while the website is read and the agent is set up.
const STATES = [
  {},
  { websiteStarted: true },
  { websiteStarted: true, liveReady: true },
  { websiteStarted: true, liveReady: true, isLive: true },
  { liveReady: false, isLive: false },
];

describe('stepRules', () => {
  it('gives every step an action in every state, so no step can block', () => {
    GUIDED_STEPS.forEach(key => {
      STATES.forEach(state => {
        expect(['start_website', 'turn_on', 'next', 'finish']).toContain(
          primaryAction(key, state)
        );
      });
    });
  });

  it('skips to the next step from every step and ends after the last', () => {
    expect(GUIDED_STEPS.map(nextStep)).toEqual([
      'test_agent',
      'agent_inbox',
      'chat_widget',
      null,
    ]);
  });

  it('starts the import until the website is given', () => {
    expect(primaryAction('knowledge')).toBe('start_website');
    expect(primaryAction('knowledge', { websiteStarted: true })).toBe('next');
  });

  it('turns the agent on only when it can answer and is not on yet', () => {
    expect(primaryAction('agent_inbox', { liveReady: true })).toBe('turn_on');
    expect(primaryAction('agent_inbox', { liveReady: false })).toBe('next');
    expect(
      primaryAction('agent_inbox', { liveReady: true, isLive: true })
    ).toBe('next');
  });

  it('finishes on the last step', () => {
    expect(primaryAction('chat_widget')).toBe('finish');
  });
});

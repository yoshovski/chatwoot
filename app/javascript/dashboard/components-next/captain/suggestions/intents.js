// What a customer asked the AI agent to do (Captain::KnowledgeGap::INTENTS), and where the owner sets it up.
// `template` is a scenario template id from scenarios/scenarioTemplates.js; `route` a page of its own.
const SCENARIOS = 'captain_assistants_scenarios_index';

export const INTENT_ACTIONS = {
  order_status: { route: 'captain_tools_connections' },
  cancel: { route: SCENARIOS },
  return: { route: SCENARIOS, template: 'returns_and_warranty' },
  booking: { route: SCENARIOS, template: 'book_a_call' },
  other: { route: SCENARIOS },
};

export const intentTarget = (intent, params) => {
  const action = INTENT_ACTIONS[intent] || INTENT_ACTIONS.other;
  return {
    name: action.route,
    params,
    query: action.template ? { template: action.template } : {},
  };
};

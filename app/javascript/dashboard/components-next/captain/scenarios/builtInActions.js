// Built-in actions are named in a scenario with fixed parameters:
// [@Save Company size](tool://update_contact_attribute?key=company_size). The AI fills only the open values.

export const ROUND_ROBIN = 'round_robin';
export const SEPARATE_MESSAGE_PHRASE = 'Send this as a separate message.';

// Minutes; the server accepts 15 minutes to 7 days.
export const FOLLOW_UP_DELAYS = [15, 30, 60, 120, 240, 1440, 2880, 4320, 10080];

export const TOOL_GROUPS = ['BUILT_IN', 'CUSTOM', 'MCP'];

export const toolGroup = tool => {
  if (tool.mcp) return 'MCP';
  if (tool.custom) return 'CUSTOM';
  return 'BUILT_IN';
};

export const needsFixedParams = tool => Boolean(tool?.built_in_action);

// Splits "update_contact_attribute?key=company_size" into its id and params.
export const parseToolReference = reference => {
  const [id, query = ''] = String(reference || '').split('?');
  return { id, params: Object.fromEntries(new URLSearchParams(query)) };
};

// Builds the reference id the editor stores after tool://, without empty values.
export const buildToolReference = (toolId, params = {}) => {
  const query = new URLSearchParams(
    Object.entries(params).filter(
      ([, value]) => value !== '' && value !== null && value !== undefined
    )
  ).toString();
  return query ? `${toolId}?${query}` : toolId;
};

// Groups tools for a menu: each item gets `groupLabel` when it starts a group, in TOOL_GROUPS order.
export const groupTools = (tools, groupLabel) =>
  TOOL_GROUPS.flatMap(group => {
    const items = (tools || []).filter(tool => toolGroup(tool) === group);
    return items.map((tool, index) =>
      index === 0 ? { ...tool, groupLabel: groupLabel(group) } : tool
    );
  });

export const formatDelay = (minutes, t) => {
  if (minutes % 1440 === 0) {
    return t(
      'CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.DELAY.DAYS',
      { count: minutes / 1440 },
      minutes / 1440
    );
  }
  if (minutes % 60 === 0) {
    return t(
      'CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.DELAY.HOURS',
      { count: minutes / 60 },
      minutes / 60
    );
  }
  return t(
    'CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.DELAY.MINUTES',
    { count: minutes },
    minutes
  );
};

// The chip text for a reference, e.g. "Save Company size" or "Assign Sales".
// lookups: { attributes, teams, agents, templates } to name the fixed values.
export const actionChipTitle = (toolId, params, lookups, t) => {
  const { attributes = [], teams = [], agents = [], templates = {} } = lookups;
  const attributeName = key =>
    attributes.find(attribute => attribute.attribute_key === key)
      ?.attribute_display_name || key;
  const teamName = id =>
    teams.find(team => String(team.id) === String(id))?.name || id;
  const templateName = key => templates[key]?.name || key;

  switch (toolId) {
    case 'update_contact_attribute':
    case 'update_conversation_attribute':
      return t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.CHIP.SAVE', {
        name: attributeName(params.key),
      });
    case 'assign_team':
      return t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.CHIP.ASSIGN', {
        name: teamName(params.team_id),
      });
    case 'assign_agent':
      if (params.agent_id === ROUND_ROBIN) {
        return params.team_id
          ? t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.CHIP.ASSIGN_NEXT_IN', {
              name: teamName(params.team_id),
            })
          : t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.CHIP.ASSIGN_NEXT');
      }
      return t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.CHIP.ASSIGN', {
        name:
          agents.find(agent => String(agent.id) === String(params.agent_id))
            ?.name || params.agent_id,
      });
    case 'email_visitor':
      return t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.CHIP.EMAIL_VISITOR', {
        name: templateName(params.template),
      });
    case 'email_team':
      return t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.CHIP.EMAIL_TEAM', {
        name: templateName(params.template),
      });
    case 'schedule_follow_up':
      return t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.CHIP.FOLLOW_UP', {
        time: formatDelay(Number(params.after), t),
      });
    default:
      return toolId;
  }
};

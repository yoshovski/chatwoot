// The upstream report pages kept under Analytics → More reports, with plain names. `activeOn` lists the detail pages.
export const MORE_REPORTS = [
  { key: 'LIVE', name: 'account_overview_reports' },
  { key: 'CONVERSATIONS', name: 'conversation_reports' },
  {
    key: 'AGENTS',
    name: 'agent_reports_index',
    activeOn: ['agent_reports_show', 'agent_reports'],
  },
  {
    key: 'LABELS',
    name: 'label_reports_index',
    activeOn: ['label_reports_show', 'label_reports'],
  },
  {
    key: 'INBOXES',
    name: 'inbox_reports_index',
    activeOn: ['inbox_reports_show', 'inbox_reports'],
  },
  {
    key: 'TEAMS',
    name: 'team_reports_index',
    activeOn: ['team_reports_show', 'team_reports'],
  },
  { key: 'RATING', name: 'csat_reports' },
  { key: 'TARGETS', name: 'sla_reports' },
  { key: 'AI_AGENT', name: 'bot_reports' },
].map(report => ({ activeOn: [], ...report }));

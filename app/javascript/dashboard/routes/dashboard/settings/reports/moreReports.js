// The upstream report pages kept under Analytics → Detailed reports, with plain names, grouped by the question they
// answer. `activeOn` lists their detail pages.
const report = (key, group, icon, name, activeOn = []) => ({
  key,
  group,
  icon,
  name,
  activeOn,
});

export const MORE_REPORTS = [
  report('LIVE', 'NOW', 'i-lucide-radio', 'account_overview_reports'),
  report(
    'CONVERSATIONS',
    'NOW',
    'i-lucide-messages-square',
    'conversation_reports'
  ),
  report('LABELS', 'NOW', 'i-lucide-tags', 'label_reports_index', [
    'label_reports_show',
    'label_reports',
  ]),
  report('AGENTS', 'WHO', 'i-lucide-user-round', 'agent_reports_index', [
    'agent_reports_show',
    'agent_reports',
  ]),
  report('TEAMS', 'WHO', 'i-lucide-users', 'team_reports_index', [
    'team_reports_show',
    'team_reports',
  ]),
  report('INBOXES', 'WHO', 'i-lucide-inbox', 'inbox_reports_index', [
    'inbox_reports_show',
    'inbox_reports',
  ]),
  report('AI_AGENT', 'QUALITY', 'i-lucide-bot', 'bot_reports'),
  report('RATING', 'QUALITY', 'i-lucide-star', 'csat_reports'),
  report('TARGETS', 'QUALITY', 'i-lucide-timer', 'sla_reports'),
];

export const MORE_REPORT_GROUPS = ['NOW', 'WHO', 'QUALITY'];

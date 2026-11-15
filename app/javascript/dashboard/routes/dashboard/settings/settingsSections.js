// The settings sections and their pages, in the order the settings home and the rail show them.
// `label` and `hint` are keys under SETTINGS_HOME.PAGES; `keywords` feed the settings search.
export const SETTINGS_SECTIONS = [
  {
    key: 'TEAM',
    icon: 'i-lucide-users',
    pages: [
      {
        key: 'TEAMMATES',
        route: 'agent_list',
        icon: 'i-lucide-square-user',
        activeOn: ['agent_list'],
      },
      {
        key: 'TEAMS',
        route: 'settings_teams_list',
        icon: 'i-lucide-users',
        activeOn: [
          'settings_teams_list',
          'settings_teams_new',
          'settings_teams_add_agents',
          'settings_teams_finish',
          'settings_teams_edit',
          'settings_teams_edit_members',
          'settings_teams_edit_finish',
        ],
      },
      {
        key: 'ROLES',
        route: 'custom_roles_list',
        icon: 'i-lucide-shield-plus',
        activeOn: ['custom_roles_list'],
      },
    ],
  },
  {
    key: 'REPLIES',
    icon: 'i-lucide-message-square-quote',
    pages: [
      {
        key: 'CANNED',
        route: 'canned_list',
        icon: 'i-lucide-message-square-quote',
        activeOn: ['canned_list'],
      },
      {
        key: 'MACROS',
        route: 'macros_wrapper',
        icon: 'i-lucide-toy-brick',
        activeOn: ['macros_wrapper', 'macros_new', 'macros_edit'],
      },
      {
        key: 'LABELS',
        route: 'labels_list',
        icon: 'i-lucide-tags',
        activeOn: ['labels_list'],
      },
      {
        key: 'ATTRIBUTES',
        route: 'attributes_list',
        icon: 'i-lucide-code',
        activeOn: ['attributes_list'],
      },
    ],
  },
  {
    key: 'AUTOMATION',
    icon: 'i-lucide-repeat',
    pages: [
      {
        key: 'RULES',
        route: 'automation_list',
        icon: 'i-lucide-repeat',
        activeOn: ['automation_list'],
      },
      {
        key: 'ASSIGNMENT',
        route: 'assignment_policy_index',
        icon: 'i-lucide-user-cog',
        activeOn: ['assignment_policy_index'],
        advancedAssignment: true,
      },
      {
        key: 'WORKFLOW',
        route: 'conversation_workflow_index',
        icon: 'i-lucide-workflow',
        activeOn: ['conversation_workflow_index'],
      },
      {
        key: 'TARGETS',
        route: 'sla_list',
        icon: 'i-lucide-clock-alert',
        activeOn: ['sla_list'],
      },
    ],
  },
  {
    key: 'ACCOUNT',
    icon: 'i-lucide-briefcase',
    pages: [
      {
        key: 'ACCOUNT',
        route: 'general_settings_index',
        icon: 'i-lucide-briefcase',
        activeOn: ['general_settings_index'],
      },
      {
        key: 'PROFILE',
        route: 'profile_settings_index',
        icon: 'i-lucide-circle-user',
        activeOn: ['profile_settings_index'],
      },
      {
        key: 'SECURITY',
        route: 'security_settings_index',
        icon: 'i-lucide-shield',
        activeOn: ['security_settings_index'],
      },
      {
        key: 'AUDIT_LOG',
        route: 'auditlogs_list',
        icon: 'i-lucide-scroll-text',
        activeOn: ['auditlogs_list'],
      },
    ],
  },
  {
    key: 'INTEGRATIONS',
    icon: 'i-lucide-blocks',
    pages: [
      {
        key: 'APPS',
        route: 'settings_applications',
        icon: 'i-lucide-blocks',
        activeOn: ['settings_applications'],
      },
      {
        key: 'TEMPLATES',
        route: 'settings_templates',
        icon: 'i-lucide-layout-template',
        activeOn: ['settings_templates'],
      },
      {
        key: 'DATA',
        route: 'settings_data_imports',
        icon: 'i-lucide-database',
        activeOn: ['settings_data_imports', 'settings_data_import_show'],
      },
    ],
  },
];

// The settings page a route belongs to, or undefined for pages outside the settings home.
export const findSettingsPage = routeName =>
  SETTINGS_SECTIONS.flatMap(section => section.pages).find(page =>
    page.activeOn.includes(routeName)
  );

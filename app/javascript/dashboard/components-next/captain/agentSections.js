// One place that says how the AI agent workspace is organised. The sidebar shows one flat
// entry per section; a page that belongs to a section with several tabs shows them at the top.
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

export const AGENT_SECTIONS = [
  {
    key: 'overview',
    icon: 'i-lucide-circle-gauge',
    tabs: [{ route: 'captain_assistants_overview_index', key: 'OVERVIEW' }],
  },
  {
    key: 'profile',
    icon: 'i-lucide-id-card',
    tabs: [{ route: 'captain_assistants_settings_index', key: 'PROFILE' }],
  },
  {
    key: 'knowledge',
    icon: 'i-lucide-book-open',
    tabs: [
      { route: 'captain_assistants_documents_index', key: 'SOURCES' },
      { route: 'captain_assistants_responses_index', key: 'FAQS' },
      { route: 'captain_assistants_faq_suggestions', key: 'SUGGESTIONS' },
      {
        route: 'captain_assistants_products_index',
        key: 'PRODUCTS',
        requires: 'shopify',
      },
    ],
  },
  {
    key: 'behavior',
    icon: 'i-lucide-message-circle-heart',
    tabs: [
      { route: 'captain_assistants_guidelines_index', key: 'REPLY_STYLE' },
      { route: 'captain_assistants_guardrails_index', key: 'RULES' },
      {
        route: 'captain_assistants_settings_customer_data_index',
        key: 'CUSTOMER_DATA',
      },
    ],
  },
  {
    key: 'handoff',
    icon: 'i-lucide-user-round-check',
    tabs: [
      { route: 'captain_assistants_settings_system_index', key: 'ROUTING' },
      {
        route: 'captain_assistants_settings_after_chat_index',
        key: 'CHAT_ENDS',
      },
    ],
  },
  {
    key: 'scenarios',
    icon: 'i-lucide-git-branch',
    tabs: [
      { route: 'captain_assistants_scenarios_index', key: 'SCENARIOS' },
      { route: 'captain_assistants_settings_leads_index', key: 'LEADS' },
    ],
  },
  {
    key: 'actions',
    icon: 'i-lucide-zap',
    tabs: [
      {
        route: 'captain_tools_index',
        key: 'BUILT_IN',
        featureFlag: FEATURE_FLAGS.CAPTAIN_CUSTOM_TOOLS,
      },
      {
        route: 'captain_tools_email_templates',
        key: 'EMAIL_TEMPLATES',
        featureFlag: FEATURE_FLAGS.CAPTAIN_CUSTOM_TOOLS,
      },
      {
        route: 'captain_tools_api',
        key: 'API_CALLS',
        featureFlag: FEATURE_FLAGS.CAPTAIN_CUSTOM_TOOLS,
        alsoActiveOn: ['captain_tools_new', 'captain_tools_edit'],
      },
      {
        route: 'captain_tools_connections',
        key: 'MCP',
        featureFlag: FEATURE_FLAGS.CAPTAIN_CUSTOM_TOOLS,
      },
    ],
  },
  {
    key: 'channels',
    icon: 'i-lucide-radio',
    tabs: [
      { route: 'captain_assistants_inboxes_index', key: 'CHANNELS' },
      { route: 'captain_assistants_settings_schedule_index', key: 'HOURS' },
      { route: 'captain_assistants_settings_audience_index', key: 'AUDIENCE' },
    ],
  },
];

const tabRoutes = tab => [tab.route, ...(tab.alsoActiveOn || [])];

export const sectionRoutes = section => section.tabs.flatMap(tabRoutes);

export const findSection = routeName =>
  AGENT_SECTIONS.find(section => sectionRoutes(section).includes(routeName));

export const isTabActive = (tab, routeName) =>
  tabRoutes(tab).includes(routeName);

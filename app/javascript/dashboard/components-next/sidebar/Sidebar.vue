<script setup>
import { h, ref, computed, onMounted, watch } from 'vue';
import { useRoute } from 'vue-router';
import { provideSidebarContext } from './provider';
import { useAccount } from 'dashboard/composables/useAccount';
import { useShopifyIntegration } from 'dashboard/composables/useShopifyIntegration';
import { useConfig } from 'dashboard/composables/useConfig';
import { useMapGetter } from 'dashboard/composables/store';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useSidebarKeyboardShortcuts } from './useSidebarKeyboardShortcuts';
import { vOnClickOutside } from '@vueuse/components';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useWindowSize } from '@vueuse/core';

import Button from 'dashboard/components-next/button/Button.vue';
import SidebarNavigation from './SidebarNavigation.vue';
import SidebarProfileMenu from './SidebarProfileMenu.vue';
import ChannelLeaf from './ChannelLeaf.vue';
import ChannelIcon from 'next/icon/ChannelIcon.vue';
import EmojiIcon from 'next/emoji-icon-picker/EmojiIcon.vue';
import SidebarAccountSwitcher from './SidebarAccountSwitcher.vue';
import Logo from 'next/icon/Logo.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import {
  SIDEBAR_SORT_SECTIONS,
  getSidebarSortOptions,
  resolveSidebarSort,
  sortSidebarItems,
} from 'dashboard/helper/sidebarSort';

const props = defineProps({
  isMobileSidebarOpen: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'closeKeyShortcutModal',
  'openKeyShortcutModal',
  'showCreateAccountModal',
  'closeMobileSidebar',
]);

const {
  accountScopedRoute,
  isOnChatwootCloud,
  isCloudFeatureEnabled,
  currentAccount,
} = useAccount();
const { isEnterprise } = useConfig();
const store = useStore();

// Calls run on the enterprise-only API (cloud runs enterprise); hide the entry
// on community so it doesn't lead to a dashboard/CTA the backend can't serve.
const isCallsAvailable = computed(
  () =>
    Boolean(currentAccount.value?.id) &&
    (isOnChatwootCloud.value || isEnterprise) &&
    isCloudFeatureEnabled(FEATURE_FLAGS.CALLS)
);
const { t } = useI18n();

const { width: windowWidth } = useWindowSize();
const isMobile = computed(() => windowWidth.value < 768);

const route = useRoute();
const uiSettings = useMapGetter('getUISettings');
const captainAssistants = useMapGetter('captainAssistants/getRecords');

const activeAssistantId = computed(() => {
  if (route.params?.assistantId) return Number(route.params.assistantId);
  const lastActive = uiSettings.value?.last_active_assistant_id;
  if (captainAssistants.value?.some(a => a.id === Number(lastActive))) {
    return Number(lastActive);
  }
  return captainAssistants.value?.[0]?.id || null;
});

const captainAssistantRoute = (name, params = {}) => {
  if (activeAssistantId.value) {
    return accountScopedRoute(name, {
      assistantId: activeAssistantId.value,
      ...params,
    });
  }
  return accountScopedRoute('captain_assistants_index', {
    navigationPath: name,
    ...params,
  });
};

const accountId = useMapGetter('getCurrentAccountId');
const currentUserId = useMapGetter('getCurrentUserID');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const hasAdvancedAssignment = computed(() => {
  return isFeatureEnabledonAccount.value(
    accountId.value,
    FEATURE_FLAGS.ADVANCED_ASSIGNMENT
  );
});

const hasConversationUnreadCounts = computed(() => {
  return isFeatureEnabledonAccount.value(
    accountId.value,
    FEATURE_FLAGS.CONVERSATION_UNREAD_COUNTS
  );
});

const hasFilteredUnreadCounts = computed(() => {
  return (
    hasConversationUnreadCounts.value &&
    isFeatureEnabledonAccount.value(
      accountId.value,
      FEATURE_FLAGS.UNREAD_COUNT_FOR_FILTERS
    )
  );
});

const fetchConversationUnreadCounts = ([currentAccountId, isEnabled]) => {
  if (!currentAccountId) return;

  if (!isEnabled) {
    store.dispatch('conversationUnreadCounts/clear');
    return;
  }

  store.dispatch('conversationUnreadCounts/get');
};

const fetchSidebarSortPreferences = ([currentAccountId, userId]) => {
  if (!currentAccountId || !userId) return;
  store.dispatch('sidebarSortPreferences/initialize');
};

const toggleShortcutModalFn = show => {
  if (show) {
    emit('openKeyShortcutModal');
  } else {
    emit('closeKeyShortcutModal');
  }
};

useSidebarKeyboardShortcuts(toggleShortcutModalFn);

const expandedItem = ref(null);

const setExpandedItem = name => {
  expandedItem.value = expandedItem.value === name ? null : name;
};

provideSidebarContext({
  expandedItem,
  setExpandedItem,
  isCollapsed: computed(() => false),
  sidebarWidth: ref(320),
  isResizing: ref(false),
});

const { isConnected: isShopifyConnected } = useShopifyIntegration();

const inboxes = useMapGetter('inboxes/getInboxes');
const labels = useMapGetter('labels/getLabelsOnSidebar');
const allUnreadCount = useMapGetter(
  'conversationUnreadCounts/getAllUnreadCount'
);
const notificationUnreadCount = useMapGetter('notifications/getUnreadCount');
const getInboxUnreadCount = useMapGetter(
  'conversationUnreadCounts/getInboxUnreadCount'
);
const getLabelUnreadCount = useMapGetter(
  'conversationUnreadCounts/getLabelUnreadCount'
);
const getTeamUnreadCount = useMapGetter(
  'conversationUnreadCounts/getTeamUnreadCount'
);
const mentionsUnreadCount = useMapGetter(
  'conversationUnreadCounts/getMentionsUnreadCount'
);
const participatingUnreadCount = useMapGetter(
  'conversationUnreadCounts/getParticipatingUnreadCount'
);
const unattendedUnreadCount = useMapGetter(
  'conversationUnreadCounts/getUnattendedUnreadCount'
);
const getFolderUnreadCount = useMapGetter(
  'conversationUnreadCounts/getFolderUnreadCount'
);
const teams = useMapGetter('teams/getMyTeams');
const contactCustomViews = useMapGetter('customViews/getContactCustomViews');
const conversationCustomViews = useMapGetter(
  'customViews/getConversationCustomViews'
);
const getSidebarSectionSort = useMapGetter(
  'sidebarSortPreferences/getSectionSort'
);

onMounted(() => {
  store.dispatch('labels/get');
  store.dispatch('inboxes/get');
  store.dispatch('notifications/unReadCount');
  store.dispatch('teams/get');
  store.dispatch('attributes/get');
  store.dispatch('customViews/get', 'conversation');
  store.dispatch('customViews/get', 'contact');
});

watch([accountId, hasConversationUnreadCounts], fetchConversationUnreadCounts, {
  immediate: true,
});

watch([accountId, currentUserId], fetchSidebarSortPreferences, {
  immediate: true,
});

const hasUnreadCountsForSection = section => {
  if (section === SIDEBAR_SORT_SECTIONS.FOLDERS) {
    return hasFilteredUnreadCounts.value;
  }

  return hasConversationUnreadCounts.value;
};

const getSortOptionsForSection = section =>
  getSidebarSortOptions(section, {
    hasUnreadCounts: hasUnreadCountsForSection(section),
  });

const getSortForSection = section =>
  resolveSidebarSort(section, getSidebarSectionSort.value(section), {
    hasUnreadCounts: hasUnreadCountsForSection(section),
  });

const updateSortPreference = (section, sortBy) => {
  store.dispatch('sidebarSortPreferences/setSectionSort', {
    section,
    sortBy,
  });
};

const buildSortConfig = section => ({
  sortOptions: getSortOptionsForSection(section),
  activeSort: getSortForSection(section),
  onSortChange: sortBy => updateSortPreference(section, sortBy),
});

const sortedFolders = computed(() =>
  sortSidebarItems(conversationCustomViews.value, {
    sortBy: getSortForSection(SIDEBAR_SORT_SECTIONS.FOLDERS),
    labelKey: view => view.name,
    unreadCountKey: view => getFolderUnreadCount.value(view.id),
  })
);

const sortedTeams = computed(() =>
  sortSidebarItems(teams.value, {
    sortBy: getSortForSection(SIDEBAR_SORT_SECTIONS.TEAMS),
    labelKey: team => team.name,
    unreadCountKey: team => getTeamUnreadCount.value(team.id),
  })
);

const sortedInboxes = computed(() =>
  sortSidebarItems(inboxes.value, {
    sortBy: getSortForSection(SIDEBAR_SORT_SECTIONS.CHANNELS),
    labelKey: inbox => inbox.name,
    unreadCountKey: inbox => getInboxUnreadCount.value(inbox.id),
  })
);

const sortedLabels = computed(() =>
  sortSidebarItems(labels.value, {
    sortBy: getSortForSection(SIDEBAR_SORT_SECTIONS.LABELS),
    labelKey: label => label.title,
    unreadCountKey: label => getLabelUnreadCount.value(label.id),
  })
);

const closeMobileSidebar = () => {
  if (!props.isMobileSidebarOpen) return;
  emit('closeMobileSidebar');
};

const newReportRoutes = () => [
  {
    name: 'Reports Agent',
    label: t('SIDEBAR.REPORTS_AGENT'),
    to: accountScopedRoute('agent_reports_index'),
    activeOn: ['agent_reports_show'],
  },
  {
    name: 'Reports Label',
    label: t('SIDEBAR.REPORTS_LABEL'),
    to: accountScopedRoute('label_reports_index'),
  },
  {
    name: 'Reports Inbox',
    label: t('SIDEBAR.REPORTS_INBOX'),
    to: accountScopedRoute('inbox_reports_index'),
    activeOn: ['inbox_reports_show'],
  },
  {
    name: 'Reports Team',
    label: t('SIDEBAR.REPORTS_TEAM'),
    to: accountScopedRoute('team_reports_index'),
    activeOn: ['team_reports_show'],
  },
];

const reportRoutes = computed(() => newReportRoutes());

const menuItems = computed(() => {
  return [
    {
      name: 'Home',
      label: t('SIDEBAR.HOME'),
      icon: 'i-lucide-house',
      to: accountScopedRoute('account_home'),
      activeOn: ['account_home', 'account_home_setup'],
    },
    {
      name: 'Inbox',
      badgeCount: notificationUnreadCount.value,
      label: t('SIDEBAR.INBOX'),
      icon: 'i-lucide-inbox',
      to: accountScopedRoute('inbox_view'),
      activeOn: ['inbox_view', 'inbox_view_conversation'],
      getterKeys: {
        count: 'notifications/getUnreadCount',
      },
    },
    {
      name: 'Conversation',
      badgeCount: notificationUnreadCount.value,
      label: t('SIDEBAR.CONVERSATIONS'),
      icon: 'i-lucide-messages-square',
      children: [
        {
          name: 'All',
          label: t('SIDEBAR.ALL_CONVERSATIONS'),
          icon: 'i-lucide-inbox',
          badgeCount: allUnreadCount.value,
          activeOn: ['inbox_conversation'],
          to: accountScopedRoute('home'),
        },
        {
          name: 'Mentions',
          label: t('SIDEBAR.MENTIONED_CONVERSATIONS'),
          icon: 'i-lucide-at-sign',
          badgeCount: hasFilteredUnreadCounts.value
            ? mentionsUnreadCount.value
            : 0,
          activeOn: ['conversation_through_mentions'],
          to: accountScopedRoute('conversation_mentions'),
        },
        {
          name: 'Participating',
          label: t('SIDEBAR.PARTICIPATING_CONVERSATIONS'),
          icon: 'i-lucide-user-round-check',
          badgeCount: hasFilteredUnreadCounts.value
            ? participatingUnreadCount.value
            : 0,
          activeOn: ['conversation_through_participating'],
          to: accountScopedRoute('conversation_participating'),
        },
        {
          name: 'Unattended',
          activeOn: ['conversation_through_unattended'],
          label: t('SIDEBAR.UNATTENDED_CONVERSATIONS'),
          icon: 'i-lucide-clock-alert',
          badgeCount: hasFilteredUnreadCounts.value
            ? unattendedUnreadCount.value
            : 0,
          to: accountScopedRoute('conversation_unattended'),
        },
        {
          name: 'Bot',
          activeOn: ['conversation_through_bot'],
          label: t('SIDEBAR.BOT_CONVERSATIONS'),
          icon: 'i-lucide-bot',
          badgeCount: 0,
          to: accountScopedRoute('conversation_bot'),
        },
        {
          name: 'Folders',
          label: t('SIDEBAR.CUSTOM_VIEWS_FOLDER'),
          icon: 'i-lucide-folder',
          activeOn: ['conversations_through_folders'],
          ...buildSortConfig(SIDEBAR_SORT_SECTIONS.FOLDERS),
          collapsible: true,
          showTreeLine: true,
          children: sortedFolders.value.map(view => ({
            name: `${view.name}-${view.id}`,
            label: view.name,
            badgeCount: hasFilteredUnreadCounts.value
              ? getFolderUnreadCount.value(view.id)
              : 0,
            to: accountScopedRoute('folder_conversations', { id: view.id }),
          })),
        },
        {
          name: 'Teams',
          label: t('SIDEBAR.TEAMS'),
          icon: 'i-lucide-users',
          activeOn: ['conversations_through_team'],
          ...buildSortConfig(SIDEBAR_SORT_SECTIONS.TEAMS),
          collapsible: true,
          showTreeLine: true,
          children: sortedTeams.value.map(team => ({
            name: `${team.name}-${team.id}`,
            label: team.name,
            badgeCount: getTeamUnreadCount.value(team.id),
            icon: team.icon
              ? h(EmojiIcon, {
                  value: team.icon,
                  color: team.icon_color,
                  class: 'size-3.5',
                })
              : undefined,
            to: accountScopedRoute('team_conversations', { teamId: team.id }),
          })),
        },
        {
          name: 'Channels',
          label: t('SIDEBAR.CHANNELS'),
          icon: 'i-lucide-mailbox',
          activeOn: ['conversation_through_inbox'],
          ...buildSortConfig(SIDEBAR_SORT_SECTIONS.CHANNELS),
          collapsible: true,
          showTreeLine: true,
          children: sortedInboxes.value.map(inbox => ({
            name: `${inbox.name}-${inbox.id}`,
            label: inbox.name,
            badgeCount: getInboxUnreadCount.value(inbox.id),
            icon: h(ChannelIcon, { inbox, class: 'size-[16px]' }),
            to: accountScopedRoute('inbox_dashboard', { inbox_id: inbox.id }),
            component: leafProps =>
              h(ChannelLeaf, {
                label: leafProps.label,
                active: leafProps.active,
                inbox,
                badgeCount: leafProps.badgeCount,
              }),
          })),
        },
        {
          name: 'Labels',
          label: t('SIDEBAR.LABELS'),
          icon: 'i-lucide-tag',
          activeOn: ['conversations_through_label'],
          ...buildSortConfig(SIDEBAR_SORT_SECTIONS.LABELS),
          collapsible: true,
          showTreeLine: true,
          children: sortedLabels.value.map(label => ({
            name: `${label.title}-${label.id}`,
            label: label.title,
            badgeCount: getLabelUnreadCount.value(label.id),
            icon: h('span', {
              class: `size-[8px] rounded-sm`,
              style: { backgroundColor: label.color },
            }),
            to: accountScopedRoute('label_conversations', {
              label: label.title,
            }),
          })),
        },
      ],
    },
    {
      name: 'Captain',
      icon: 'i-lucide-bot-message-square',
      // The branded product name ("Octave AI Agents") is too long for the panel title.
      label: t('PLATFORM_NAV.AI_AGENTS'),
      children: [
        {
          name: 'Knowledge',
          label: t('PLATFORM_NAV.KNOWLEDGE'),
          icon: 'i-lucide-database',
          activeOn: [
            'captain_assistants_documents_index',
            'captain_assistants_responses_index',
            'captain_assistants_faq_suggestions',
            'captain_assistants_products_index',
          ],
          children: [
            {
              name: 'captain_assistants_documents_index',
              label: t('PLATFORM_NAV.DATA_SOURCES'),
              icon: 'i-lucide-files',
              to: captainAssistantRoute('captain_assistants_documents_index'),
              activeOn: ['captain_assistants_documents_index'],
            },
            {
              name: 'captain_assistants_responses_index',
              label: t('PLATFORM_NAV.FAQS'),
              icon: 'i-lucide-messages-square',
              to: captainAssistantRoute('captain_assistants_responses_index'),
              activeOn: ['captain_assistants_responses_index'],
            },
            {
              name: 'captain_assistants_faq_suggestions',
              label: t('PLATFORM_NAV.SUGGESTIONS'),
              icon: 'i-lucide-lightbulb',
              to: captainAssistantRoute('captain_assistants_faq_suggestions'),
              activeOn: ['captain_assistants_faq_suggestions'],
            },
            ...(isShopifyConnected.value
              ? [
                  {
                    name: 'captain_assistants_products_index',
                    label: t('CAPTAIN.KNOWLEDGE.TABS.PRODUCTS'),
                    icon: 'i-lucide-shopping-bag',
                    to: captainAssistantRoute(
                      'captain_assistants_products_index'
                    ),
                    activeOn: ['captain_assistants_products_index'],
                  },
                ]
              : []),
          ],
        },
        {
          name: 'Behavior',
          label: t('PLATFORM_NAV.BEHAVIOR'),
          icon: 'i-lucide-sliders-horizontal',
          children: [
            {
              name: 'captain_assistants_guidelines_index',
              label: t('PLATFORM_NAV.INSTRUCTIONS'),
              icon: 'i-lucide-scan-text',
              to: captainAssistantRoute('captain_assistants_guidelines_index'),
              activeOn: ['captain_assistants_guidelines_index'],
            },
            {
              name: 'captain_assistants_guardrails_index',
              label: t('PLATFORM_NAV.BOUNDARIES'),
              icon: 'i-lucide-shield-check',
              to: captainAssistantRoute('captain_assistants_guardrails_index'),
              activeOn: ['captain_assistants_guardrails_index'],
            },
            {
              name: 'captain_assistants_settings_system_index',
              label: t('PLATFORM_NAV.HANDOFF'),
              icon: 'i-lucide-user-round-check',
              to: captainAssistantRoute(
                'captain_assistants_settings_system_index'
              ),
              activeOn: ['captain_assistants_settings_system_index'],
            },
            {
              name: 'captain_assistants_settings_after_chat_index',
              label: t('PLATFORM_NAV.AFTER_CHAT'),
              icon: 'i-lucide-circle-check',
              to: captainAssistantRoute(
                'captain_assistants_settings_after_chat_index'
              ),
              activeOn: ['captain_assistants_settings_after_chat_index'],
            },
          ],
        },
        {
          name: 'Actions',
          label: t('PLATFORM_NAV.ACTIONS'),
          icon: 'i-lucide-workflow',
          children: [
            {
              name: 'captain_assistants_settings_leads_index',
              label: t('CAPTAIN.ASSISTANTS.SETTINGS.LEADS.TITLE'),
              icon: 'i-lucide-contact-round',
              to: captainAssistantRoute(
                'captain_assistants_settings_leads_index'
              ),
              activeOn: ['captain_assistants_settings_leads_index'],
            },
            {
              name: 'captain_assistants_scenarios_index',
              label: t('SIDEBAR.CAPTAIN_SCENARIOS'),
              icon: 'i-lucide-git-branch',
              to: captainAssistantRoute('captain_assistants_scenarios_index'),
              activeOn: ['captain_assistants_scenarios_index'],
            },
            {
              name: 'Tools',
              label: t('SIDEBAR.CAPTAIN_TOOLS'),
              icon: 'i-lucide-wrench',
              to: captainAssistantRoute('captain_tools_index'),
              activeOn: ['captain_tools_index'],
            },
          ],
        },
        {
          name: 'Configure',
          label: t('PLATFORM_NAV.CONFIGURE'),
          icon: 'i-lucide-settings-2',
          children: [
            {
              name: 'captain_assistants_settings_index',
              label: t('PLATFORM_NAV.IDENTITY'),
              icon: 'i-lucide-contact',
              to: captainAssistantRoute('captain_assistants_settings_index'),
              activeOn: ['captain_assistants_settings_index'],
            },
          ],
        },
        {
          name: 'Manage',
          label: t('PLATFORM_NAV.MANAGE'),
          icon: 'i-lucide-sliders',
          children: [
            {
              name: 'captain_assistants_overview_index',
              label: t('SIDEBAR.CAPTAIN_OVERVIEW'),
              icon: 'i-lucide-circle-gauge',
              to: captainAssistantRoute('captain_assistants_overview_index'),
              activeOn: ['captain_assistants_overview_index'],
            },
            {
              name: 'captain_assistants_inboxes_index',
              label: t('PLATFORM_NAV.CHANNELS'),
              icon: 'i-lucide-radio',
              to: captainAssistantRoute('captain_assistants_inboxes_index'),
              activeOn: ['captain_assistants_inboxes_index'],
            },
            {
              name: 'captain_assistants_settings_schedule_index',
              label: t('CAPTAIN.ASSISTANTS.SETTINGS.TABS.WORKING_HOURS'),
              icon: 'i-lucide-clock',
              to: captainAssistantRoute(
                'captain_assistants_settings_schedule_index'
              ),
              activeOn: ['captain_assistants_settings_schedule_index'],
            },
            {
              name: 'captain_assistants_settings_audience_index',
              label: t('PLATFORM_NAV.AUDIENCE'),
              icon: 'i-lucide-users',
              to: captainAssistantRoute(
                'captain_assistants_settings_audience_index'
              ),
              activeOn: ['captain_assistants_settings_audience_index'],
            },
          ],
        },
      ],
    },
    ...(isFeatureEnabledonAccount.value(
      accountId.value,
      FEATURE_FLAGS.NATIVE_AI_KNOWLEDGE
    )
      ? [
          {
            name: 'Knowledge',
            label: t('SIDEBAR.KNOWLEDGE'),
            icon: 'i-lucide-library',
            to: accountScopedRoute('native_knowledge_index'),
            activeOn: ['native_knowledge_index', 'native_knowledge_show'],
          },
        ]
      : []),
    ...(isCallsAvailable.value
      ? [
          {
            name: 'Calls',
            label: t('SIDEBAR.CALLS'),
            icon: 'i-lucide-phone',
            to: accountScopedRoute('calls_dashboard_index'),
            activeOn: ['calls_dashboard_index'],
          },
        ]
      : []),
    {
      name: 'Contacts',
      label: t('SIDEBAR.CONTACTS'),
      icon: 'i-lucide-users-round',
      children: [
        {
          name: 'All Contacts',
          label: t('SIDEBAR.ALL_CONTACTS'),
          to: accountScopedRoute(
            'contacts_dashboard_index',
            {},
            { page: 1, search: undefined }
          ),
          activeOn: ['contacts_dashboard_index', 'contacts_edit'],
        },
        {
          name: 'Active',
          label: t('SIDEBAR.ACTIVE'),
          to: accountScopedRoute('contacts_dashboard_active'),
          activeOn: ['contacts_dashboard_active'],
        },
        {
          name: 'Segments',
          icon: 'i-lucide-group',
          label: t('SIDEBAR.CUSTOM_VIEWS_SEGMENTS'),
          collapsible: true,
          showTreeLine: true,
          children: contactCustomViews.value.map(view => ({
            name: `${view.name}-${view.id}`,
            label: view.name,
            to: accountScopedRoute(
              'contacts_dashboard_segments_index',
              { segmentId: view.id },
              { page: 1 }
            ),
            activeOn: [
              'contacts_dashboard_segments_index',
              'contacts_edit_segment',
            ],
          })),
        },
        {
          name: 'Tagged With',
          icon: 'i-lucide-tag',
          label: t('SIDEBAR.TAGGED_WITH'),
          collapsible: true,
          showTreeLine: true,
          children: labels.value.map(label => ({
            name: `${label.title}-${label.id}`,
            label: label.title,
            icon: h('span', {
              class: `size-[8px] rounded-sm`,
              style: { backgroundColor: label.color },
            }),
            to: accountScopedRoute(
              'contacts_dashboard_labels_index',
              { label: label.title },
              { page: 1, search: undefined }
            ),
            activeOn: [
              'contacts_dashboard_labels_index',
              'contacts_edit_label',
            ],
          })),
        },
      ],
    },
    {
      name: 'Companies',
      label: t('SIDEBAR.COMPANIES'),
      icon: 'i-lucide-building-2',
      children: [
        {
          name: 'All Companies',
          label: t('SIDEBAR.ALL_COMPANIES'),
          to: accountScopedRoute(
            'companies_dashboard_index',
            {},
            { page: 1, search: undefined }
          ),
          activeOn: ['companies_dashboard_index', 'companies_dashboard_show'],
        },
      ],
    },
    {
      name: 'Reports',
      label: t('SIDEBAR.REPORTS'),
      icon: 'i-lucide-chart-no-axes-column',
      children: [
        {
          name: 'Report Overview',
          label: t('SIDEBAR.REPORTS_OVERVIEW'),
          to: accountScopedRoute('account_overview_reports'),
        },
        {
          name: 'Report Conversation',
          label: t('SIDEBAR.REPORTS_CONVERSATION'),
          to: accountScopedRoute('conversation_reports'),
        },
        ...reportRoutes.value,
        {
          name: 'Reports CSAT',
          label: t('SIDEBAR.CSAT'),
          to: accountScopedRoute('csat_reports'),
        },
        {
          name: 'Reports SLA',
          label: t('SIDEBAR.REPORTS_SLA'),
          to: accountScopedRoute('sla_reports'),
        },
        {
          name: 'Reports Bot',
          label: t('SIDEBAR.REPORTS_BOT'),
          to: accountScopedRoute('bot_reports'),
        },
      ],
    },
    {
      name: 'Campaigns',
      label: t('SIDEBAR.CAMPAIGNS'),
      icon: 'i-lucide-megaphone',
      children: [
        {
          name: 'Live chat',
          label: t('SIDEBAR.LIVE_CHAT'),
          to: accountScopedRoute('campaigns_livechat_index'),
        },
        {
          name: 'SMS',
          label: t('SIDEBAR.SMS'),
          to: accountScopedRoute('campaigns_sms_index'),
        },
        {
          name: 'WhatsApp',
          label: t('SIDEBAR.WHATSAPP'),
          to: accountScopedRoute('campaigns_whatsapp_index'),
        },
      ],
    },
    {
      name: 'Portals',
      label: t('SIDEBAR.HELP_CENTER.TITLE'),
      icon: 'i-lucide-book-open-text',
      children: [
        {
          name: 'Articles',
          label: t('SIDEBAR.HELP_CENTER.ARTICLES'),
          activeOn: [
            'portals_articles_index',
            'portals_articles_new',
            'portals_articles_edit',
          ],
          to: accountScopedRoute('portals_index', {
            navigationPath: 'portals_articles_index',
          }),
        },
        {
          name: 'Categories',
          label: t('SIDEBAR.HELP_CENTER.CATEGORIES'),
          activeOn: [
            'portals_categories_index',
            'portals_categories_articles_index',
            'portals_categories_articles_edit',
          ],
          to: accountScopedRoute('portals_index', {
            navigationPath: 'portals_categories_index',
          }),
        },
        {
          name: 'Locales',
          label: t('SIDEBAR.HELP_CENTER.LOCALES'),
          activeOn: ['portals_locales_index'],
          to: accountScopedRoute('portals_index', {
            navigationPath: 'portals_locales_index',
          }),
        },
        {
          name: 'Settings',
          label: t('SIDEBAR.HELP_CENTER.SETTINGS'),
          activeOn: ['portals_settings_index'],
          to: accountScopedRoute('portals_index', {
            navigationPath: 'portals_settings_index',
          }),
        },
      ],
    },
    {
      name: 'Billing',
      label: isOnChatwootCloud.value
        ? t('SIDEBAR.BILLING')
        : t('ACCOUNT_SUBSCRIPTION.TITLE'),
      icon: 'i-lucide-credit-card',
      activeOn: ['billing_settings_index', 'billing_settings_usage'],
      to: accountScopedRoute('billing_settings_index'),
    },
    {
      name: 'Settings',
      label: t('SIDEBAR.SETTINGS'),
      icon: 'i-lucide-settings',
      children: [
        {
          name: 'Settings Account Settings',
          label: t('SIDEBAR.ACCOUNT_SETTINGS'),
          icon: 'i-lucide-briefcase',
          to: accountScopedRoute('general_settings_index'),
        },
        // {
        //   name: 'Settings Captain',
        //   label: t('SIDEBAR.CAPTAIN_AI'),
        //   icon: 'i-woot-captain',
        //   to: accountScopedRoute('captain_settings_index'),
        // },
        {
          name: 'Settings Agents',
          label: t('SIDEBAR.AGENTS'),
          icon: 'i-lucide-square-user',
          to: accountScopedRoute('agent_list'),
        },
        {
          name: 'Settings Teams',
          label: t('SIDEBAR.TEAMS'),
          icon: 'i-lucide-users',
          activeOn: [
            'settings_teams_list',
            'settings_teams_new',
            'settings_teams_finish',
            'settings_teams_add_agents',
            'settings_teams_show',
            'settings_teams_edit',
            'settings_teams_edit_members',
            'settings_teams_edit_finish',
          ],
          to: accountScopedRoute('settings_teams_list'),
        },
        ...(hasAdvancedAssignment.value
          ? [
              {
                name: 'Settings Agent Assignment',
                label: t('SIDEBAR.AGENT_ASSIGNMENT'),
                icon: 'i-lucide-user-cog',
                activeOn: [
                  'assignment_policy_index',
                  'agent_assignment_policy_index',
                  'agent_assignment_policy_create',
                  'agent_assignment_policy_edit',
                  'agent_capacity_policy_index',
                  'agent_capacity_policy_create',
                  'agent_capacity_policy_edit',
                ],
                to: accountScopedRoute('assignment_policy_index'),
              },
            ]
          : []),
        {
          name: 'Settings Inboxes',
          label: t('SIDEBAR.INBOXES'),
          icon: 'i-lucide-inbox',
          activeOn: [
            'settings_inbox_list',
            'settings_inbox_show',
            'settings_inbox_new',
            'settings_inbox_finish',
            'settings_inboxes_page_channel',
            'settings_inboxes_add_agents',
          ],
          to: accountScopedRoute('settings_inbox_list'),
        },
        {
          name: 'Settings Templates',
          label: t('SIDEBAR.WHATSAPP_TEMPLATES'),
          icon: 'i-lucide-layout-template',
          to: accountScopedRoute('settings_templates'),
        },
        {
          name: 'Settings Labels',
          label: t('SIDEBAR.LABELS'),
          icon: 'i-lucide-tags',
          to: accountScopedRoute('labels_list'),
        },
        {
          name: 'Settings Custom Attributes',
          label: t('SIDEBAR.CUSTOM_ATTRIBUTES'),
          icon: 'i-lucide-code',
          to: accountScopedRoute('attributes_list'),
        },
        {
          name: 'Settings Automation',
          label: t('SIDEBAR.AUTOMATION'),
          icon: 'i-lucide-repeat',
          to: accountScopedRoute('automation_list'),
        },
        {
          name: 'Settings Agent Bots',
          label: t('SIDEBAR.AGENT_BOTS'),
          icon: 'i-lucide-bot',
          to: accountScopedRoute('agent_bots'),
        },
        {
          name: 'Settings Macros',
          label: t('SIDEBAR.MACROS'),
          icon: 'i-lucide-toy-brick',
          to: accountScopedRoute('macros_wrapper'),
        },
        {
          name: 'Settings Canned Responses',
          label: t('SIDEBAR.CANNED_RESPONSES'),
          icon: 'i-lucide-message-square-quote',
          to: accountScopedRoute('canned_list'),
        },
        {
          name: 'Settings Integrations',
          label: t('SIDEBAR.INTEGRATIONS'),
          icon: 'i-lucide-blocks',
          to: accountScopedRoute('settings_applications'),
        },
        {
          name: 'Settings Data',
          label: t('SIDEBAR.DATA'),
          icon: 'i-lucide-database',
          to: accountScopedRoute('settings_data_imports'),
          activeOn: ['settings_data_exports', 'settings_data_import_show'],
        },
        {
          name: 'Settings Audit Logs',
          label: t('SIDEBAR.AUDIT_LOGS'),
          icon: 'i-lucide-briefcase',
          to: accountScopedRoute('auditlogs_list'),
        },
        {
          name: 'Settings Custom Roles',
          label: t('SIDEBAR.CUSTOM_ROLES'),
          icon: 'i-lucide-shield-plus',
          to: accountScopedRoute('custom_roles_list'),
        },
        {
          name: 'Settings Sla',
          label: t('SIDEBAR.SLA'),
          icon: 'i-lucide-clock-alert',
          to: accountScopedRoute('sla_list'),
        },
        {
          name: 'Conversation Workflow',
          label: t('SIDEBAR.CONVERSATION_WORKFLOW'),
          icon: 'i-lucide-workflow',
          to: accountScopedRoute('conversation_workflow_index'),
        },
        {
          name: 'Settings Security',
          label: t('SIDEBAR.SECURITY'),
          icon: 'i-lucide-shield',
          to: accountScopedRoute('security_settings_index'),
        },
      ],
    },
  ];
});
</script>

<template>
  <aside
    v-on-click-outside="[
      closeMobileSidebar,
      {
        ignore: [
          '#mobile-sidebar-launcher',
          '[data-popover-content]',
          '[data-popover-backdrop]',
        ],
      },
    ]"
    class="fixed top-0 z-40 flex h-full w-fit max-w-full shrink-0 border-e border-n-weak bg-n-background transition-transform start-0 md:relative md:translate-x-0"
    :class="{
      'ltr:-translate-x-full rtl:translate-x-full':
        !isMobileSidebarOpen && isMobile,
    }"
  >
    <SidebarNavigation :items="menuItems" @navigate="closeMobileSidebar">
      <template #brand><Logo class="size-6 text-n-blue-text" /></template>
      <template #profile>
        <SidebarProfileMenu
          is-collapsed
          @open-key-shortcut-modal="emit('openKeyShortcutModal')"
        />
      </template>
      <template #account>
        <SidebarAccountSwitcher
          @show-create-account-modal="emit('showCreateAccountModal')"
        />
      </template>
      <template #actions>
        <RouterLink
          :to="{ name: 'search' }"
          :aria-label="t('COMBOBOX.SEARCH_PLACEHOLDER')"
          class="grid size-8 place-items-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2"
        >
          <span class="i-lucide-search size-4" />
        </RouterLink>
        <ComposeConversation align="end">
          <template #trigger>
            <Button
              icon="i-lucide-pen-line"
              :aria-label="t('PLATFORM_NAV.COMPOSE')"
              variant="ghost"
              color="slate"
              size="sm"
            />
          </template>
        </ComposeConversation>
      </template>
    </SidebarNavigation>
  </aside>
</template>

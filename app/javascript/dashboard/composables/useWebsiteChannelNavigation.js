import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { INBOX_TYPES } from 'dashboard/helper/inbox';

/* eslint-disable @intlify/vue-i18n/no-dynamic-keys -- Fixed website channel labels. */
const groups = [
  {
    name: 'WIDGET',
    items: [
      ['appearance', 'APPEARANCE', 'i-lucide-palette'],
      ['welcome', 'WELCOME', 'i-lucide-panel-top'],
    ],
  },
  {
    name: 'CONVERSATIONS',
    items: [
      ['conversation', 'CONVERSATION', 'i-lucide-messages-square'],
      ['pre-chat-form', 'PRE_CHAT', 'i-lucide-list-checks'],
      ['csat', 'RATING', 'i-lucide-star'],
    ],
  },
  {
    name: 'TEAM',
    items: [
      ['collaborators', 'COLLABORATORS', 'i-lucide-users-round'],
      ['business-hours', 'HOURS', 'i-lucide-clock-3'],
      ['ai-agent', 'AGENT', 'i-lucide-bot'],
    ],
  },
  {
    name: 'WEBSITE',
    items: [
      ['installation', 'INSTALL', 'i-lucide-code-xml'],
      ['security', 'SECURITY', 'i-lucide-shield'],
    ],
  },
];

export const useWebsiteChannelNavigation = () => {
  const route = useRoute();
  const store = useStore();
  const { t } = useI18n();

  const isWebsiteSettings = computed(
    () =>
      route.name === 'settings_inbox_show' &&
      store?.getters['inboxes/getInbox']?.(route.params.inboxId)
        ?.channel_type === INBOX_TYPES.WEB
  );

  const routeFor = key => ({
    name: 'settings_inbox_show',
    params: { ...route.params, tab: key === 'appearance' ? '' : key },
  });

  const hasCaptain = computed(() =>
    store?.getters['accounts/isFeatureEnabledonAccount']?.(
      Number(route.params.accountId),
      FEATURE_FLAGS.CAPTAIN
    )
  );

  const navigation = computed(() =>
    groups.map(({ name, items }) => ({
      name,
      label: t(`INBOX_MGMT.WEBSITE_SETTINGS.GROUPS.${name}`),
      children: items
        .filter(([key]) => key !== 'ai-agent' || hasCaptain.value)
        .map(([key, translation, icon]) => ({
          name: key,
          icon,
          to: routeFor(key),
          label: t(`INBOX_MGMT.WEBSITE_SETTINGS.PAGES.${translation}.TITLE`),
          description: t(
            `INBOX_MGMT.WEBSITE_SETTINGS.PAGES.${translation}.DESCRIPTION`
          ),
        })),
    }))
  );

  const activePage = computed(() => {
    const tab =
      route.params.tab === 'bot-configuration' ? 'ai-agent' : route.params.tab;
    const links = navigation.value.flatMap(group => group.children);
    return links.find(link => link.name === tab) || links[0];
  });

  return { activePage, hasCaptain, isWebsiteSettings, navigation, routeFor };
};

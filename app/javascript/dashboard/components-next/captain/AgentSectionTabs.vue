<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useShopifyIntegration } from 'dashboard/composables/useShopifyIntegration';
import { findSection, isTabActive } from './agentSections';

// Tabs for the section the current page belongs to. Hidden when a section has one page.
const route = useRoute();
const { t } = useI18n();
const { isConnected: isShopifyConnected } = useShopifyIntegration();
const accountId = useMapGetter('getCurrentAccountId');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const section = computed(() => findSection(route.name));
// Editor pages (new/edit) belong to a tab but show their own back link instead of the tabs.
const isSubPage = computed(() =>
  (section.value?.tabs || []).some(tab =>
    (tab.alsoActiveOn || []).includes(route.name)
  )
);

const tabs = computed(() =>
  (section.value?.tabs || [])
    .filter(
      tab =>
        (tab.requires !== 'shopify' || isShopifyConnected.value) &&
        (!tab.featureFlag ||
          isFeatureEnabledonAccount.value(accountId.value, tab.featureFlag))
    )
    .map(tab => ({
      ...tab,
      label: t(`CAPTAIN.AGENT_UX.TABS.${tab.key}`),
      active: isTabActive(tab, route.name),
      to: {
        name: tab.route,
        params: {
          accountId: route.params.accountId,
          assistantId: route.params.assistantId,
        },
      },
    }))
);
</script>

<template>
  <nav
    v-if="tabs.length > 1 && !isSubPage"
    class="flex gap-6 overflow-x-auto border-b border-n-weak"
    :aria-label="t(`CAPTAIN.AGENT_UX.SECTIONS.${section.key.toUpperCase()}`)"
  >
    <router-link
      v-for="tab in tabs"
      :key="tab.route"
      :to="tab.to"
      class="relative pb-3 text-sm font-medium whitespace-nowrap transition-colors"
      :class="
        tab.active ? 'text-n-slate-12' : 'text-n-slate-11 hover:text-n-slate-12'
      "
      :aria-current="tab.active ? 'page' : undefined"
    >
      {{ tab.label }}
      <span
        v-if="tab.active"
        class="absolute inset-x-0 bottom-0 h-0.5 rounded-full bg-n-brand"
        aria-hidden="true"
      />
    </router-link>
  </nav>
</template>

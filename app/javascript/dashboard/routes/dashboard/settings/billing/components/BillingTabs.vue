<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const tabs = computed(() => [
  {
    name: 'billing_settings_index',
    label: t('ACCOUNT_SUBSCRIPTION.TABS.BILLING'),
  },
  {
    name: 'billing_settings_usage',
    label: t('ACCOUNT_SUBSCRIPTION.TABS.USAGE'),
  },
]);
const activeIndex = computed(() =>
  Math.max(
    0,
    tabs.value.findIndex(tab => tab.name === route.name)
  )
);
const onChange = tab => {
  if (tab.name !== route.name) router.push({ name: tab.name });
};
</script>

<template>
  <TabBar
    :tabs="tabs"
    :initial-active-tab="activeIndex"
    @tab-changed="onChange"
  />
</template>

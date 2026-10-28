<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccountSubscription } from 'dashboard/composables/useAccountSubscription';
import Button from 'dashboard/components-next/button/Button.vue';
import BillingTabs from './components/BillingTabs.vue';
import DailyUsageChart from './components/DailyUsageChart.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';

const { t } = useI18n();
const { billing, loading, loadFailed, refresh } = useAccountSubscription();
onMounted(() => refresh({ sync: false }));

const days = computed(() => billing.value?.daily_usage || []);
const charts = computed(() => [
  {
    key: 'ai',
    title: t('ACCOUNT_SUBSCRIPTION.PRODUCTS.AI_CONVERSATIONS'),
    help: t('ACCOUNT_SUBSCRIPTION.USAGE_PAGE.AI_HELP'),
    color: 'rgb(var(--blue-9))',
    days: days.value.map(day => ({ date: day.date, value: day.consumed })),
  },
  {
    key: 'all',
    title: t('ACCOUNT_SUBSCRIPTION.PRODUCTS.ALL_CONVERSATIONS'),
    help: t('ACCOUNT_SUBSCRIPTION.USAGE_PAGE.ALL_HELP'),
    color: 'rgb(var(--teal-9))',
    days: days.value.map(day => ({ date: day.date, value: day.conversations })),
  },
]);
</script>

<template>
  <SettingsLayout
    content-sized
    :is-loading="loading"
    :loading-message="t('ACCOUNT_SUBSCRIPTION.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('ACCOUNT_SUBSCRIPTION.USAGE_PAGE.TITLE')"
        :description="t('ACCOUNT_SUBSCRIPTION.USAGE_PAGE.DESCRIPTION')"
      >
        <template #tabs>
          <BillingTabs />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <div
        v-if="loadFailed"
        class="mb-4 flex items-center justify-between gap-4 rounded-xl border border-n-weak bg-n-solid-1 p-4"
        role="alert"
      >
        <p class="m-0 text-sm text-n-slate-11">
          {{ t('ACCOUNT_SUBSCRIPTION.LOAD_ERROR') }}
        </p>
        <Button
          :label="t('ACCOUNT_SUBSCRIPTION.RETRY')"
          variant="outline"
          color="slate"
          size="sm"
          @click="refresh"
        />
      </div>
      <div v-if="billing" class="flex flex-col gap-4">
        <DailyUsageChart
          v-for="chart in charts"
          :key="chart.key"
          :title="chart.title"
          :help="chart.help"
          :color="chart.color"
          :days="chart.days"
        />
      </div>
    </template>
  </SettingsLayout>
</template>

<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { RouterView, useRoute, useRouter } from 'vue-router';
import PageFrame from 'dashboard/components-next/kit/PageFrame.vue';
import PageHeader from 'dashboard/components-next/kit/PageHeader.vue';
import RangeSelector from 'dashboard/components-next/captain/pageComponents/overview/RangeSelector.vue';
import {
  isSupportedPeriod,
  periodFromQuery,
  periodWindow,
} from './analyticsView';

// The Analytics section. The sidebar is the navigation; this frame names the current view and holds the one period
// control (kept in the URL), which every view except the reports hub reads from the route.
const { t, locale } = useI18n();
const route = useRoute();
const router = useRouter();

const period = computed(() => periodFromQuery(route.query.period));
const hasPeriod = computed(() => route.name !== 'analytics_reports');

const titles = computed(() => ({
  analytics_overview: t('ANALYTICS.TITLE'),
  analytics_ai_agent: t('ANALYTICS.TABS.AI_AGENT'),
  analytics_team: t('ANALYTICS.TABS.TEAM'),
  analytics_rating: t('ANALYTICS.TABS.RATING'),
  analytics_reports: t('ANALYTICS.REPORTS.TITLE'),
}));
const title = computed(() => titles.value[route.name]);
const description = computed(() => {
  if (!hasPeriod.value) return t('ANALYTICS.REPORTS.SUBTITLE');
  const { since, until } = periodWindow(period.value);
  const format = value =>
    new Date(value * 1000).toLocaleString(locale.value, {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  return t('ANALYTICS.CONTEXT', {
    since: format(since),
    until: format(until),
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
  });
});
const unsupportedPeriod = computed(
  () => !isSupportedPeriod(route.query.period)
);

const selectPeriod = days => {
  if (days === period.value) return;
  router.push({ query: { ...route.query, period: days } });
};
</script>

<template>
  <PageFrame workspace>
    <template #header>
      <PageHeader
        class="workspace-widget workspace-inset"
        :title="title"
        :description="description"
      >
        <template v-if="hasPeriod" #action>
          <RangeSelector
            :model-value="String(period)"
            @update:model-value="selectPeriod"
          />
        </template>
      </PageHeader>
    </template>
    <p v-if="unsupportedPeriod" role="status" class="text-sm text-n-amber-11">
      {{ t('ANALYTICS.UNSUPPORTED_PERIOD') }}
    </p>
    <RouterView :period="period" />
  </PageFrame>
</template>

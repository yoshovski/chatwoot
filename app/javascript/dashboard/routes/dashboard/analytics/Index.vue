<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { RouterView, useRoute, useRouter } from 'vue-router';
import PageFrame from 'dashboard/components-next/kit/PageFrame.vue';
import PageHeader from 'dashboard/components-next/kit/PageHeader.vue';
import { PERIODS, periodFromQuery } from './analyticsView';

// The Analytics section. The sidebar is the navigation; this frame names the current view and holds the one period
// control (kept in the URL), which every view except the reports hub reads from the route.
const { t } = useI18n();
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
const description = computed(() =>
  hasPeriod.value
    ? t('ANALYTICS.SUBTITLE', { days: period.value })
    : t('ANALYTICS.REPORTS.SUBTITLE')
);

const selectPeriod = days => {
  if (days === period.value) return;
  router.replace({ query: { ...route.query, period: days } });
};
</script>

<template>
  <PageFrame>
    <template #header>
      <PageHeader :title="title" :description="description">
        <template v-if="hasPeriod" #action>
          <div
            role="group"
            :aria-label="t('ANALYTICS.PERIOD.LABEL')"
            class="flex rounded-full bg-n-alpha-2 p-0.5"
          >
            <button
              v-for="days in PERIODS"
              :key="days"
              type="button"
              class="rounded-full px-3 py-1 text-xs font-medium"
              :class="
                days === period
                  ? 'bg-n-solid-2 text-n-slate-12 shadow-sm'
                  : 'text-n-slate-11 hover:text-n-slate-12'
              "
              :aria-pressed="days === period"
              @click="selectPeriod(days)"
            >
              {{ t('ANALYTICS.PERIOD.DAYS', { days }) }}
            </button>
          </div>
        </template>
      </PageHeader>
    </template>
    <RouterView :period="period" />
  </PageFrame>
</template>

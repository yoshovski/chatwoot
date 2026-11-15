<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { RouterLink, RouterView, useRoute, useRouter } from 'vue-router';
import Button from 'dashboard/components-next/button/Button.vue';
import PageFrame from 'dashboard/components-next/kit/PageFrame.vue';
import PageHeader from 'dashboard/components-next/kit/PageHeader.vue';
import { TABS } from './routes';
import { PERIODS, periodFromQuery } from './analyticsView';

// The Analytics section: one period control (kept in the URL) and the tabs. Each tab reads the period from the route.
const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const period = computed(() => periodFromQuery(route.query.period));

const selectPeriod = days => {
  if (days === period.value) return;
  router.replace({ query: { ...route.query, period: days } });
};

const tabLabels = computed(() => ({
  OVERVIEW: t('ANALYTICS.TABS.OVERVIEW'),
  AI_AGENT: t('ANALYTICS.TABS.AI_AGENT'),
  TEAM: t('ANALYTICS.TABS.TEAM'),
  RATING: t('ANALYTICS.TABS.RATING'),
}));

const tabs = computed(() =>
  TABS.map(tab => ({
    ...tab,
    label: tabLabels.value[tab.key],
    to: { name: tab.name, query: route.query },
    active: route.name === tab.name,
  }))
);

const openMoreReports = () => router.push({ name: 'account_overview_reports' });
</script>

<template>
  <PageFrame>
    <template #header>
      <PageHeader
        :title="t('ANALYTICS.TITLE')"
        :description="t('ANALYTICS.SUBTITLE', { days: period })"
      >
        <template #action>
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
          <Button
            :label="t('ANALYTICS.MORE_REPORTS')"
            icon="i-lucide-table-2"
            size="sm"
            variant="faded"
            color="slate"
            @click="openMoreReports"
          />
        </template>
      </PageHeader>
      <nav
        :aria-label="t('ANALYTICS.TABS.LABEL')"
        class="-mb-1 flex gap-1 overflow-x-auto border-b border-n-weak"
      >
        <RouterLink
          v-for="tab in tabs"
          :key="tab.name"
          :to="tab.to"
          class="-mb-px shrink-0 border-b-2 px-3 py-2 text-sm font-medium"
          :class="
            tab.active
              ? 'border-n-blue-9 text-n-slate-12'
              : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
          "
          :aria-current="tab.active ? 'page' : undefined"
        >
          {{ tab.label }}
        </RouterLink>
      </nav>
    </template>
    <RouterView :period="period" />
  </PageFrame>
</template>

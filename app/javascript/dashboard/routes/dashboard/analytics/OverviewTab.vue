<script setup>
import { computed, onMounted, toRef } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';
import TopicsCard from '../home/components/TopicsCard.vue';
import DayChart from './components/DayChart.vue';
import MetricTiles from './components/MetricTiles.vue';
import PeopleList from './components/PeopleList.vue';
import {
  analyticsMetrics,
  chartDays,
  metricView,
  peopleRows,
} from './analyticsView';
import { LOADERS, useAnalyticsData } from './useAnalyticsData';

// Overview: four numbers, conversations by day for the AI agent and the team, then topics and the busiest people.
const props = defineProps({
  period: { type: [Number, String], required: true },
});

const { t } = useI18n();
const store = useStore();
const agents = useMapGetter('agents/getAgents');
const { data, isLoading, hasError, failures, reload } = useAnalyticsData(
  toRef(props, 'period'),
  LOADERS
);

const metrics = computed(() => analyticsMetrics(data.value));
const tiles = computed(() => [
  metricView(
    'conversations',
    metrics.value.conversations,
    t('ANALYTICS.METRICS.CONVERSATIONS'),
    t
  ),
  metricView(
    'resolved',
    metrics.value.resolved,
    t('ANALYTICS.METRICS.RESOLVED'),
    t
  ),
  metricView(
    'first_reply',
    metrics.value.first_reply,
    t('ANALYTICS.METRICS.FIRST_REPLY'),
    t
  ),
  metricView('rating', metrics.value.rating, t('ANALYTICS.METRICS.RATING'), t),
]);
const days = computed(() =>
  chartDays(data.value.activity?.days, day => [day.ai, day.team])
);
const series = computed(() => [
  { label: t('ANALYTICS.CHART.AI'), total: t('ANALYTICS.CHART.AI_TOTAL') },
  { label: t('ANALYTICS.CHART.TEAM'), total: t('ANALYTICS.CHART.TEAM_TOTAL') },
]);
const people = computed(() => peopleRows(data.value.agents, agents.value));

onMounted(() => store.dispatch('agents/get'));
</script>

<template>
  <MetricTiles
    :tiles="tiles"
    :is-loading="isLoading"
    :has-error="hasError"
    :has-partial-error="Object.values(failures).some(Boolean) && !hasError"
    @retry="reload"
  />
  <SectionCard
    :title="t('ANALYTICS.CHART.TITLE')"
    :link-label="t('ANALYTICS.LINKS.CONVERSATIONS')"
    :to="{ name: 'conversation_reports' }"
  >
    <DayChart
      :days="days"
      :series="series"
      :period="period"
      :note="t('ANALYTICS.CHART.NOTE')"
      :empty-text="t('ANALYTICS.CHART.EMPTY')"
      :is-loading="isLoading"
      :has-error="failures.activity"
      @retry="reload"
    />
  </SectionCard>
  <div class="grid grid-cols-1 gap-4 lg:grid-cols-2">
    <TopicsCard
      :topics="data.activity?.topics || []"
      :is-loading="isLoading"
      :has-error="failures.activity"
      @retry="reload"
    />
    <SectionCard
      :title="t('ANALYTICS.PEOPLE.TITLE')"
      :link-label="t('ANALYTICS.LINKS.TEAM')"
      :to="{ name: 'analytics_team', query: { period } }"
    >
      <PeopleList
        :rows="people"
        :empty-text="t('ANALYTICS.PEOPLE.EMPTY')"
        :is-loading="isLoading"
        :has-error="failures.agents"
        @retry="reload"
      />
    </SectionCard>
  </div>
</template>

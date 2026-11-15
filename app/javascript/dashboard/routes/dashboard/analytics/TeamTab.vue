<script setup>
import { computed, onMounted, toRef } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import SummaryReportsAPI from 'dashboard/api/summaryReports';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';
import DayChart from './components/DayChart.vue';
import MetricTiles from './components/MetricTiles.vue';
import PeopleList from './components/PeopleList.vue';
import {
  analyticsMetrics,
  chartDays,
  metricView,
  peopleRows,
  teamRows,
} from './analyticsView';
import { LOADERS, useAnalyticsData } from './useAnalyticsData';

// Team: what your people solved and how fast they replied, the conversations they replied in per day, each person and
// each team.
const props = defineProps({ period: { type: Number, required: true } });

const { t } = useI18n();
const store = useStore();
const agents = useMapGetter('agents/getAgents');
const teams = useMapGetter('teams/getTeams');

const { data, isLoading, hasError, reload } = useAnalyticsData(
  toRef(props, 'period'),
  {
    ...LOADERS,
    teams: ({ since, until }) =>
      SummaryReportsAPI.getTeamReports({ since, until }),
  }
);

const metrics = computed(() => analyticsMetrics(data.value));
const tiles = computed(() => [
  metricView(
    'team_solved',
    metrics.value.team_solved,
    t('ANALYTICS.METRICS.TEAM_SOLVED'),
    t
  ),
  metricView(
    'first_reply',
    metrics.value.first_reply,
    t('ANALYTICS.METRICS.FIRST_REPLY'),
    t
  ),
  metricView(
    'resolution_time',
    metrics.value.resolution_time,
    t('ANALYTICS.METRICS.RESOLUTION_TIME'),
    t
  ),
  metricView('handed', metrics.value.handed, t('ANALYTICS.METRICS.HANDED'), t),
]);
const days = computed(() =>
  chartDays(data.value.activity?.days, day => [day.team])
);
const series = computed(() => [
  { label: t('ANALYTICS.CHART.TEAM'), total: t('ANALYTICS.CHART.TEAM_TOTAL') },
]);
const people = computed(() => peopleRows(data.value.agents, agents.value));
const teamList = computed(() => teamRows(data.value.teams, teams.value));

onMounted(() => {
  store.dispatch('agents/get');
  store.dispatch('teams/get');
});
</script>

<template>
  <MetricTiles
    :tiles="tiles"
    :is-loading="isLoading"
    :has-error="hasError"
    @retry="reload"
  />
  <SectionCard :title="t('ANALYTICS.TEAM.CHART_TITLE')">
    <DayChart
      :days="days"
      :series="series"
      :period="period"
      :note="t('ANALYTICS.CHART.NOTE')"
      :empty-text="t('ANALYTICS.TEAM.EMPTY')"
      :is-loading="isLoading"
      :has-error="hasError"
      @retry="reload"
    />
  </SectionCard>
  <div class="grid grid-cols-1 gap-4 lg:grid-cols-2">
    <SectionCard
      :title="t('ANALYTICS.PEOPLE.TITLE')"
      :link-label="t('ANALYTICS.LINKS.PEOPLE')"
      :to="{ name: 'agent_reports_index' }"
    >
      <PeopleList
        :rows="people"
        :limit="8"
        :empty-text="t('ANALYTICS.PEOPLE.EMPTY')"
        :is-loading="isLoading"
      />
    </SectionCard>
    <SectionCard
      :title="t('ANALYTICS.TEAM.TEAMS_TITLE')"
      :link-label="t('ANALYTICS.LINKS.TEAMS')"
      :to="{ name: 'team_reports_index' }"
    >
      <PeopleList
        :rows="teamList"
        :limit="8"
        :empty-text="t('ANALYTICS.TEAM.NO_TEAMS')"
        :is-loading="isLoading"
      />
    </SectionCard>
  </div>
</template>

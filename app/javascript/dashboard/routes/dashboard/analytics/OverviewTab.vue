<script setup>
import { computed, onMounted, toRef } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { dayLabels } from '../home/homeView';
import { metricView, overviewMetrics, teamRows } from './analyticsView';
import { useAnalyticsData } from './useAnalyticsData';
import OverviewTiles from './components/OverviewTiles.vue';
import OverviewStory from './components/OverviewStory.vue';
import OverviewCompare from './components/OverviewCompare.vue';

const props = defineProps({ period: { type: Number, required: true } });

const { t, locale } = useI18n();
const store = useStore();
const agents = useMapGetter('agents/getAgents');

const { activity, report, agentSummary, isLoading, hasError, reload } =
  useAnalyticsData(toRef(props, 'period'));

// Design step only (README "Design step"): ?co_variant=a|b|c, read once, dev builds only.
const VARIANTS = { a: OverviewTiles, b: OverviewStory, c: OverviewCompare };
const variant = import.meta.env.DEV
  ? new URLSearchParams(window.location.search).get('co_variant')
  : null;
const Layout = VARIANTS[variant] || OverviewTiles;

const labels = computed(() => ({
  conversations: t('ANALYTICS.METRICS.CONVERSATIONS'),
  ai_conversations: t('ANALYTICS.METRICS.AI_CONVERSATIONS'),
  resolved: t('ANALYTICS.METRICS.RESOLVED'),
  handed: t('ANALYTICS.METRICS.HANDED'),
  first_reply: t('ANALYTICS.METRICS.FIRST_REPLY'),
  team_solved: t('ANALYTICS.METRICS.TEAM_SOLVED'),
  rating: t('ANALYTICS.METRICS.RATING'),
}));
const raw = computed(() => overviewMetrics(activity.value, report.value));
const metrics = computed(() =>
  Object.fromEntries(
    Object.entries(raw.value).map(([key, metric]) => [
      key,
      {
        ...metricView(key, metric, t),
        label: labels.value[key],
        raw: metric,
      },
    ])
  )
);
const days = computed(() =>
  dayLabels(activity.value?.days || [], props.period, locale.value)
);
const team = computed(() => teamRows(agentSummary.value, agents.value));

onMounted(() => store.dispatch('agents/get'));
</script>

<template>
  <component
    :is="Layout"
    :metrics="metrics"
    :days="days"
    :raw-days="activity?.days || []"
    :topics="activity?.topics || []"
    :team="team"
    :period="period"
    :is-loading="isLoading"
    :has-error="hasError"
    @retry="reload"
  />
</template>

<script setup>
import { computed, toRef } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import CaptainAssistantAPI from 'dashboard/api/captain/assistant';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';
import TopicsCard from '../home/components/TopicsCard.vue';
import DayChart from './components/DayChart.vue';
import MetricTiles from './components/MetricTiles.vue';
import AgentsList from './components/AgentsList.vue';
import { aiDays, analyticsMetrics, metricView } from './analyticsView';
import { LOADERS, useAnalyticsData } from './useAnalyticsData';

// AI agent: what it answered, solved and handed on, per day; what customers asked; each AI agent with its own numbers
// and a way into its page.
const props = defineProps({
  period: { type: [Number, String], required: true },
});

const { t } = useI18n();
const store = useStore();
const assistants = useMapGetter('captainAssistants/getRecords');

const { data, isLoading, hasError, failures, reload } = useAnalyticsData(
  toRef(props, 'period'),
  { activity: LOADERS.activity }
);
// Each AI agent's numbers for the same days (Captain::AssistantStatsBuilder), loaded once the list is known.
const perAgent = useAnalyticsData(toRef(props, 'period'), {
  agents: async ({ period }) => {
    if (!assistants.value.length) {
      await store.dispatch('captainAssistants/get');
    }
    const records = [...assistants.value];
    const responses = await Promise.all(
      records.map(assistant =>
        CaptainAssistantAPI.getMetrics({
          assistantId: assistant.id,
          range: String(period),
        })
      )
    );
    return {
      data: records.map((assistant, index) => ({
        id: assistant.id,
        name: assistant.name,
        metrics: responses[index].data,
      })),
    };
  },
});

const metrics = computed(() => analyticsMetrics(data.value));
const tiles = computed(() => [
  metricView(
    'ai_conversations',
    metrics.value.ai_conversations,
    t('ANALYTICS.METRICS.AI_CONVERSATIONS'),
    t
  ),
  metricView(
    'resolved',
    metrics.value.resolved,
    t('ANALYTICS.METRICS.RESOLVED'),
    t
  ),
  metricView('handed', metrics.value.handed, t('ANALYTICS.METRICS.HANDED'), t),
  metricView(
    'product_answers',
    metrics.value.product_answers,
    t('ANALYTICS.METRICS.PRODUCT_ANSWERS'),
    t
  ),
]);
const days = computed(() => aiDays(data.value.activity));
const series = computed(() => [
  { label: t('ANALYTICS.AI.STAYED'), total: t('ANALYTICS.AI.STAYED_TOTAL') },
  { label: t('ANALYTICS.AI.HANDED'), total: t('ANALYTICS.AI.HANDED_TOTAL') },
]);
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
    :title="t('ANALYTICS.AI.CHART_TITLE')"
    :link-label="t('ANALYTICS.LINKS.AI_AGENT')"
    :to="{ name: 'bot_reports' }"
  >
    <DayChart
      :days="days"
      :series="series"
      :period="period"
      :note="t('ANALYTICS.AI.NOTE')"
      :empty-text="t('ANALYTICS.AI.EMPTY')"
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
    <SectionCard :title="t('ANALYTICS.AI.AGENTS_TITLE')">
      <AgentsList
        :agents="perAgent.data.value.agents || []"
        :is-loading="perAgent.isLoading.value"
        :has-error="perAgent.hasError.value"
        @retry="perAgent.reload"
      />
    </SectionCard>
  </div>
</template>

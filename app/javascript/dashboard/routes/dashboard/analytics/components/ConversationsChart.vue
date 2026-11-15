<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import DayBars from 'dashboard/components-next/kit/DayBars.vue';
import EmptyState from 'dashboard/components-next/kit/EmptyState.vue';
import CardError from '../../home/components/CardError.vue';

// Conversations per day, AI agent and team stacked, with a sentence for screen readers.
const props = defineProps({
  days: { type: Array, default: () => [] },
  isLoading: { type: Boolean, default: false },
  hasError: { type: Boolean, default: false },
});
const emit = defineEmits(['retry']);
const { t } = useI18n();

const totals = computed(() =>
  props.days.reduce(
    (sum, day) => ({ ai: sum.ai + day.ai, team: sum.team + day.team }),
    { ai: 0, team: 0 }
  )
);
const isEmpty = computed(() => !totals.value.ai && !totals.value.team);
const summary = computed(() =>
  t('ANALYTICS.CHART.SUMMARY', {
    days: props.days.length,
    ai: totals.value.ai,
    team: totals.value.team,
  })
);
</script>

<template>
  <span
    v-if="isLoading"
    class="h-40 w-full animate-pulse rounded bg-n-alpha-2"
    aria-busy="true"
  />
  <CardError v-else-if="hasError" @retry="emit('retry')" />
  <EmptyState
    v-else-if="isEmpty"
    icon="i-lucide-chart-column"
    :title="t('ANALYTICS.CHART.EMPTY')"
  />
  <figure v-else class="m-0 flex flex-col gap-2">
    <DayBars
      :days="days"
      :label="t('ANALYTICS.CHART.TITLE')"
      :ai-label="t('ANALYTICS.CHART.AI')"
      :team-label="t('ANALYTICS.CHART.TEAM')"
    />
    <figcaption class="sr-only">{{ summary }}</figcaption>
  </figure>
</template>

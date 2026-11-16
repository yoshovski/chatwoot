<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import DayChart from 'dashboard/routes/dashboard/analytics/components/DayChart.vue';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';

const props = defineProps({
  // [{ date: 'YYYY-MM-DD', ai, team }]
  days: { type: Array, default: () => [] },
  period: { type: Number, default: 7 },
  isLoading: { type: Boolean, default: false },
  hasError: { type: Boolean, default: false },
});

const emit = defineEmits(['retry']);

const { t } = useI18n();

const chartDays = computed(() =>
  props.days.map(day => ({
    date: day.date,
    values: [day.ai || 0, day.team || 0],
  }))
);

const series = computed(() => [
  { label: t('HOME.V2.DAYS.AI'), total: t('HOME.V2.DAYS.AI') },
  { label: t('HOME.V2.DAYS.TEAM'), total: t('HOME.V2.DAYS.TEAM') },
]);
</script>

<template>
  <SectionCard :title="t('HOME.V2.DAYS.TITLE')">
    <DayChart
      :days="chartDays"
      :series="series"
      :period="period"
      :empty-text="t('HOME.V2.DAYS.EMPTY')"
      :is-loading="isLoading"
      :has-error="hasError"
      @retry="emit('retry')"
    />
  </SectionCard>
</template>

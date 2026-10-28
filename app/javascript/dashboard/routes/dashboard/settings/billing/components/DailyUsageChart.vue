<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { LineChart } from '@chatwoot/viz';

const props = defineProps({
  title: { type: String, required: true },
  help: { type: String, required: true },
  // [{ date: 'YYYY-MM-DD', value }]
  days: { type: Array, required: true },
  color: { type: String, required: true },
});

const AXIS_LABELS = 5;
const { t, locale } = useI18n();
const number = value => new Intl.NumberFormat(locale.value).format(value);
const dayLabel = date =>
  new Date(`${date}T12:00:00Z`).toLocaleDateString(locale.value, {
    day: 'numeric',
    month: 'short',
    timeZone: 'UTC',
  });

const total = computed(() => props.days.reduce((sum, day) => sum + day.value, 0));
const chart = computed(() => ({
  categories: props.days.map(day => dayLabel(day.date)),
  series: [
    {
      id: 'usage',
      label: props.title,
      color: props.color,
      pointBorderColor: 'rgb(var(--card-color))',
      data: props.days.map(day => day.value),
    },
  ],
}));
// Keep the date axis legible; tooltips keep every day.
const axisLabels = computed(() => {
  const { categories } = chart.value;
  if (categories.length <= AXIS_LABELS) return categories;
  return Array.from(
    { length: AXIS_LABELS },
    (_, index) =>
      categories[Math.round(((categories.length - 1) * index) / (AXIS_LABELS - 1))]
  );
});
const domain = computed(() => [
  0,
  Math.max(4, Math.ceil(Math.max(...props.days.map(day => day.value)) / 4) * 4),
]);
</script>

<template>
  <section
    class="flex min-w-0 flex-col gap-4 rounded-xl border border-n-weak bg-n-solid-1 p-4 sm:p-5"
  >
    <div class="flex flex-wrap items-start justify-between gap-3">
      <div class="flex min-w-0 flex-col gap-1">
        <h2 class="m-0 text-base font-semibold text-n-slate-12">{{ title }}</h2>
        <p class="m-0 text-xs text-n-slate-11">{{ help }}</p>
      </div>
      <span
        class="shrink-0 rounded-md bg-n-alpha-2 px-2 py-1 text-xs font-medium tabular-nums text-n-slate-12"
      >
        {{ t('ACCOUNT_SUBSCRIPTION.USAGE_PAGE.TOTAL', { count: number(total) }) }}
      </span>
    </div>
    <template v-if="total > 0">
      <LineChart
        :data="chart"
        :format-value="number"
        :y-domain="domain"
        :height="200"
        :point-radius="2"
        :show-values="false"
        :x-inset="0"
        :aria-label="title"
        class="w-full [&_.cw-viz-line\_\_x-tick]:hidden [--cw-viz-line-label-color:rgb(var(--slate-11))] [--cw-viz-line-axis-color:rgb(var(--slate-4))] [--cw-viz-line-tooltip-background:rgb(var(--solid-2))] [--cw-viz-line-tooltip-color:rgb(var(--slate-12))] [--cw-viz-line-tooltip-border-color:rgb(var(--border-strong))]"
      />
      <div
        aria-hidden="true"
        class="relative -mt-7 flex justify-between gap-2 ps-14 pe-6 text-[0.625rem] text-n-slate-11"
      >
        <span v-for="label in axisLabels" :key="label">{{ label }}</span>
      </div>
    </template>
    <p
      v-else
      class="m-0 flex h-32 items-center justify-center rounded-lg bg-n-alpha-1 px-4 text-center text-sm text-n-slate-11"
    >
      {{ t('ACCOUNT_SUBSCRIPTION.USAGE_PAGE.EMPTY') }}
    </p>
  </section>
</template>

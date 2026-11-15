<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import EmptyState from 'dashboard/components-next/kit/EmptyState.vue';
import CardError from '../../home/components/CardError.vue';
import { chartScale } from '../analyticsView';

// One bar per day, one or two series stacked (blue below, amber on top), with each series' total, a scale, the day
// totals for a week and every day's numbers on hover or keyboard focus.
const props = defineProps({
  // [{ date: '2026-11-09', values: [first, second?] }]
  days: { type: Array, default: () => [] },
  // [{ label, total }]: what each value is, in stacking order; `total` names the period sum above the chart.
  series: { type: Array, required: true },
  period: { type: Number, required: true },
  note: { type: String, default: '' },
  emptyText: { type: String, required: true },
  isLoading: { type: Boolean, default: false },
  hasError: { type: Boolean, default: false },
});
const emit = defineEmits(['retry']);
const { t, locale } = useI18n();

// A month shows every fifth date under the bars, every tenth on a phone, so the dates never overlap.
const LABEL_EVERY = 5;
const LABEL_EVERY_NARROW = 10;
const TONES = [
  { bar: 'bg-n-blue-9', dot: 'bg-n-blue-9' },
  { bar: 'bg-n-amber-8', dot: 'bg-n-amber-8' },
];
const TOOLTIP_ALIGN = {
  start: 'start-0',
  center: 'start-1/2 -translate-x-1/2 rtl:translate-x-1/2',
  end: 'end-0',
};

const sum = values => values.reduce((total, value) => total + value, 0);

const totals = computed(() =>
  props.series.map((_, index) => sum(props.days.map(day => day.values[index])))
);
const isEmpty = computed(() => !sum(totals.value));
const scale = computed(() =>
  chartScale(Math.max(...props.days.map(day => sum(day.values)), 0))
);
const isWeek = computed(() => props.period <= 7);

// Keep the hover card inside the chart at both ends.
const tooltipAlign = index => {
  if (index < 2) return 'start';
  if (index > props.days.length - 3) return 'end';
  return 'center';
};

// "Mon 9" for a week, "Nov 9" for a month.
const dayLabel = date =>
  isWeek.value
    ? `${date.toLocaleDateString(locale.value, { weekday: 'short' })} ${date.getDate()}`
    : date.toLocaleDateString(locale.value, { day: 'numeric', month: 'short' });

const percent = value => `${(value / scale.value.top) * 100}%`;

const bars = computed(() =>
  props.days.map((day, index) => {
    const date = new Date(`${day.date}T12:00:00`);
    const total = sum(day.values);
    const fullDate = date.toLocaleDateString(locale.value, {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
    });
    const showLabel = isWeek.value || index % LABEL_EVERY === 0;
    return {
      key: day.date,
      total,
      fullDate,
      height: percent(total),
      // Top series first, so it stacks above the first one.
      segments: day.values
        .map((value, position) => ({
          position,
          share: total ? `${(value / total) * 100}%` : '0%',
        }))
        .reverse(),
      values: day.values.map((value, position) => ({
        position,
        value,
        label: props.series[position].label,
      })),
      label: showLabel ? dayLabel(date) : '',
      wideOnly: !isWeek.value && index % LABEL_EVERY_NARROW !== 0,
      align: tooltipAlign(index),
      ariaLabel: t('ANALYTICS.CHART.DAY', {
        date: fullDate,
        values: day.values
          .map((value, position) => `${props.series[position].label} ${value}`)
          .join(', '),
      }),
    };
  })
);
</script>

<template>
  <span
    v-if="isLoading"
    class="h-56 w-full animate-pulse rounded bg-n-alpha-2"
    aria-busy="true"
  />
  <CardError v-else-if="hasError" @retry="emit('retry')" />
  <EmptyState
    v-else-if="isEmpty"
    icon="i-lucide-chart-column"
    :title="emptyText"
  />
  <figure v-else class="m-0 flex flex-col gap-4">
    <dl class="m-0 flex flex-wrap gap-x-8 gap-y-2">
      <div
        v-for="(item, index) in series"
        :key="item.label"
        class="flex flex-col"
      >
        <dt class="inline-flex items-center gap-1.5 text-xs text-n-slate-11">
          <span class="size-2 rounded-sm" :class="TONES[index].dot" />
          {{ item.total }}
        </dt>
        <dd
          class="m-0 font-display text-2xl font-semibold tabular-nums text-n-slate-12"
        >
          {{ totals[index] }}
        </dd>
      </div>
    </dl>

    <div class="flex gap-2">
      <div
        class="relative h-48 w-8 shrink-0 text-end text-xs tabular-nums text-n-slate-10"
        aria-hidden="true"
      >
        <span
          v-for="tick in scale.ticks"
          :key="tick"
          class="absolute end-0 -translate-y-1/2"
          :style="{ top: `${100 - (tick / scale.top) * 100}%` }"
        >
          {{ tick }}
        </span>
      </div>
      <div class="flex min-w-0 flex-1 flex-col gap-2">
        <div class="relative h-48">
          <span
            v-for="tick in scale.ticks"
            :key="tick"
            class="absolute inset-x-0 border-t border-dashed border-n-weak"
            :style="{ top: `${100 - (tick / scale.top) * 100}%` }"
            aria-hidden="true"
          />
          <ol
            class="relative m-0 flex h-full list-none items-end gap-0.5 p-0 sm:gap-2"
          >
            <li
              v-for="bar in bars"
              :key="bar.key"
              tabindex="0"
              class="group relative flex h-full min-w-0 flex-1 flex-col justify-end rounded outline-none focus-visible:ring-2 focus-visible:ring-n-blue-9"
              :aria-label="bar.ariaLabel"
            >
              <span
                v-if="isWeek && bar.total"
                class="mb-1 text-center text-xs font-medium tabular-nums text-n-slate-11"
                aria-hidden="true"
              >
                {{ bar.total }}
              </span>
              <span
                class="mx-auto flex w-full max-w-12 flex-col justify-end gap-px overflow-hidden rounded-t-md group-hover:opacity-80"
                :style="{ height: bar.height }"
                aria-hidden="true"
              >
                <span
                  v-for="segment in bar.segments"
                  :key="segment.position"
                  class="w-full shrink-0"
                  :class="TONES[segment.position].bar"
                  :style="{ height: segment.share }"
                />
              </span>
              <span
                class="pointer-events-none absolute top-0 z-10 hidden w-max min-w-40 flex-col gap-1 rounded-lg bg-n-solid-1 px-3 py-2 text-xs shadow-lg outline outline-1 outline-n-container group-hover:flex group-focus-visible:flex"
                :class="TOOLTIP_ALIGN[bar.align]"
                aria-hidden="true"
              >
                <span class="font-medium text-n-slate-12">
                  {{ bar.fullDate }}
                </span>
                <span
                  v-for="item in bar.values"
                  :key="item.position"
                  class="flex items-center justify-between gap-4"
                >
                  <span
                    class="inline-flex items-center gap-1.5 text-n-slate-11"
                  >
                    <span
                      class="size-2 rounded-sm"
                      :class="TONES[item.position].dot"
                    />
                    {{ item.label }}
                  </span>
                  <span class="tabular-nums text-n-slate-12">
                    {{ item.value }}
                  </span>
                </span>
              </span>
            </li>
          </ol>
        </div>
        <div class="flex gap-0.5 sm:gap-2" aria-hidden="true">
          <span
            v-for="bar in bars"
            :key="bar.key"
            class="min-w-0 flex-1 whitespace-nowrap text-center text-xs text-n-slate-10"
          >
            <span :class="{ 'hidden sm:inline': bar.wideOnly }">
              {{ bar.label }}
            </span>
          </span>
        </div>
      </div>
    </div>
    <figcaption v-if="note" class="text-xs text-n-slate-11">
      {{ note }}
    </figcaption>
  </figure>
</template>

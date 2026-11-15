<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import EmptyState from 'dashboard/components-next/kit/EmptyState.vue';
import CardError from '../../home/components/CardError.vue';
import { chartScale } from '../analyticsView';

// Conversations per day, AI agent and team stacked, with the period's totals, a scale, the day totals for a week and
// every day's numbers on hover or keyboard focus.
const props = defineProps({
  // [{ date: '2026-11-09', ai, team }]
  days: { type: Array, default: () => [] },
  period: { type: Number, required: true },
  isLoading: { type: Boolean, default: false },
  hasError: { type: Boolean, default: false },
});
const emit = defineEmits(['retry']);
const { t, locale } = useI18n();

// A month shows every fifth day under the bars, so the labels stay readable.
const LABEL_EVERY = 5;

const totals = computed(() =>
  props.days.reduce(
    (sum, day) => ({ ai: sum.ai + day.ai, team: sum.team + day.team }),
    { ai: 0, team: 0 }
  )
);
const isEmpty = computed(() => !totals.value.ai && !totals.value.team);
const scale = computed(() =>
  chartScale(Math.max(...props.days.map(day => day.ai + day.team), 0))
);
const isWeek = computed(() => props.period <= 7);

// Keep the hover card inside the chart at both ends.
const tooltipAlign = index => {
  if (index < 2) return 'start';
  if (index > props.days.length - 3) return 'end';
  return 'center';
};

// "Mon 9" for a week, "9 Nov" for a month.
const dayLabel = date => {
  const day = date.getDate();
  return isWeek.value
    ? `${date.toLocaleDateString(locale.value, { weekday: 'short' })} ${day}`
    : date.toLocaleDateString(locale.value, { day: 'numeric', month: 'short' });
};

const percent = value => `${(value / scale.value.top) * 100}%`;

const bars = computed(() =>
  props.days.map((day, index) => {
    const date = new Date(`${day.date}T12:00:00`);
    const total = day.ai + day.team;
    const showLabel =
      isWeek.value ||
      index % LABEL_EVERY === 0 ||
      index === props.days.length - 1;
    return {
      key: day.date,
      total,
      height: percent(total),
      teamShare: total ? `${(day.team / total) * 100}%` : '0%',
      label: showLabel ? dayLabel(date) : '',
      fullDate: date.toLocaleDateString(locale.value, {
        weekday: 'long',
        day: 'numeric',
        month: 'long',
      }),
      aiCount: day.ai,
      teamCount: day.team,
      align: tooltipAlign(index),
    };
  })
);

const TOOLTIP_ALIGN = {
  start: 'start-0',
  center: 'start-1/2 -translate-x-1/2 rtl:translate-x-1/2',
  end: 'end-0',
};
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
    :title="t('ANALYTICS.CHART.EMPTY')"
  />
  <figure v-else class="m-0 flex flex-col gap-4">
    <dl class="m-0 flex flex-wrap gap-x-8 gap-y-2">
      <div class="flex flex-col">
        <dt class="inline-flex items-center gap-1.5 text-xs text-n-slate-11">
          <span class="size-2 rounded-sm bg-n-blue-9" />
          {{ t('ANALYTICS.CHART.AI_TOTAL') }}
        </dt>
        <dd
          class="m-0 font-display text-2xl font-semibold tabular-nums text-n-slate-12"
        >
          {{ totals.ai }}
        </dd>
      </div>
      <div class="flex flex-col">
        <dt class="inline-flex items-center gap-1.5 text-xs text-n-slate-11">
          <span class="size-2 rounded-sm bg-n-amber-8" />
          {{ t('ANALYTICS.CHART.TEAM_TOTAL') }}
        </dt>
        <dd
          class="m-0 font-display text-2xl font-semibold tabular-nums text-n-slate-12"
        >
          {{ totals.team }}
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
            class="relative m-0 flex h-full list-none items-end gap-1 p-0 sm:gap-2"
          >
            <li
              v-for="bar in bars"
              :key="bar.key"
              tabindex="0"
              class="group relative flex h-full min-w-0 flex-1 flex-col justify-end rounded outline-none focus-visible:ring-2 focus-visible:ring-n-blue-9"
              :aria-label="
                t('ANALYTICS.CHART.DAY', {
                  date: bar.fullDate,
                  ai: bar.aiCount,
                  team: bar.teamCount,
                })
              "
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
                  class="w-full shrink-0 bg-n-amber-8"
                  :style="{ height: bar.teamShare }"
                />
                <span class="w-full flex-1 bg-n-blue-9" />
              </span>
              <span
                class="pointer-events-none absolute top-0 z-10 hidden w-max min-w-40 flex-col gap-1 rounded-lg bg-n-solid-1 px-3 py-2 text-xs shadow-lg outline outline-1 outline-n-container group-hover:flex group-focus-visible:flex"
                :class="TOOLTIP_ALIGN[bar.align]"
                aria-hidden="true"
              >
                <span class="font-medium text-n-slate-12">
                  {{ bar.fullDate }}
                </span>
                <span class="flex items-center justify-between gap-4">
                  <span
                    class="inline-flex items-center gap-1.5 text-n-slate-11"
                  >
                    <span class="size-2 rounded-sm bg-n-blue-9" />
                    {{ t('ANALYTICS.CHART.AI') }}
                  </span>
                  <span class="tabular-nums text-n-slate-12">
                    {{ bar.aiCount }}
                  </span>
                </span>
                <span class="flex items-center justify-between gap-4">
                  <span
                    class="inline-flex items-center gap-1.5 text-n-slate-11"
                  >
                    <span class="size-2 rounded-sm bg-n-amber-8" />
                    {{ t('ANALYTICS.CHART.TEAM') }}
                  </span>
                  <span class="tabular-nums text-n-slate-12">
                    {{ bar.teamCount }}
                  </span>
                </span>
              </span>
            </li>
          </ol>
        </div>
        <div class="flex gap-1 sm:gap-2" aria-hidden="true">
          <span
            v-for="bar in bars"
            :key="bar.key"
            class="min-w-0 flex-1 overflow-visible whitespace-nowrap text-center text-xs text-n-slate-10"
          >
            {{ bar.label }}
          </span>
        </div>
      </div>
    </div>
    <figcaption class="text-xs text-n-slate-11">
      {{ t('ANALYTICS.CHART.NOTE') }}
    </figcaption>
  </figure>
</template>

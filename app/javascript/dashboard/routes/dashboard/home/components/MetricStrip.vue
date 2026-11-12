<script setup>
import Sparkline from 'dashboard/components-next/kit/Sparkline.vue';
import CardError from './CardError.vue';

// The period's numbers as one slim strip above "Needs you".
defineProps({
  // [{ key, label, value, change, changeTone, points, tone }]
  metrics: { type: Array, default: () => [] },
  // Days in the period, for the "compared with" tooltip.
  period: { type: Number, required: true },
  isLoading: { type: Boolean, default: false },
  hasError: { type: Boolean, default: false },
});

const emit = defineEmits(['retry']);

const CHANGE_TONES = {
  good: 'text-n-teal-11',
  bad: 'text-n-ruby-11',
  neutral: 'text-n-slate-11',
};
const LINE_TONES = {
  blue: 'text-n-blue-9',
  teal: 'text-n-teal-9',
  amber: 'text-n-amber-9',
  violet: 'text-n-violet-9',
};
</script>

<template>
  <div
    v-if="hasError"
    class="rounded-card bg-n-solid-2 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
  >
    <CardError @retry="emit('retry')" />
  </div>
  <div
    v-else
    class="grid grid-cols-2 gap-px overflow-hidden rounded-card bg-n-weak shadow-card outline outline-1 -outline-offset-1 outline-n-container lg:grid-cols-5"
  >
    <div
      v-for="metric in metrics"
      :key="metric.key"
      class="flex min-w-0 items-center justify-between gap-2 bg-n-solid-2 px-4 py-3 last:col-span-2 lg:last:col-span-1"
    >
      <div class="flex min-w-0 flex-col">
        <span class="truncate text-xs text-n-slate-11">
          {{ metric.label }}
        </span>
        <span
          v-if="isLoading"
          class="my-1 h-6 w-12 animate-pulse rounded bg-n-alpha-2"
          aria-busy="true"
        />
        <span
          v-else
          class="font-display text-xl font-semibold tabular-nums text-n-slate-12"
        >
          {{ metric.value }}
        </span>
        <span
          v-if="!isLoading && metric.change"
          class="text-xs"
          :class="CHANGE_TONES[metric.changeTone]"
          :title="$t('HOME.V2.CHANGE.COMPARED', { days: period })"
        >
          {{ metric.change }}
        </span>
      </div>
      <Sparkline
        v-if="!isLoading && metric.points.some(Boolean)"
        :points="metric.points"
        class="hidden h-8 w-12 shrink-0 sm:block"
        :class="LINE_TONES[metric.tone]"
      />
    </div>
  </div>
</template>

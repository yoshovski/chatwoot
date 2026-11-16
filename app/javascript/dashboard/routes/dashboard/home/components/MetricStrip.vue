<script setup>
import CardError from './CardError.vue';

// The period's numbers as one clean strip above "Needs you".
defineProps({
  // [{ key, label, value, change, changeTone, tone }]
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
      class="flex min-w-0 flex-col gap-1 bg-n-solid-2 px-4 py-3.5 last:col-span-2 lg:last:col-span-1"
    >
      <span class="truncate text-xs font-medium text-n-slate-11">
        {{ metric.label }}
      </span>
      <span
        v-if="isLoading"
        class="my-1 h-7 w-14 animate-pulse rounded bg-n-alpha-2"
        aria-busy="true"
      />
      <div v-else class="flex items-baseline justify-between gap-2">
        <span
          class="font-display text-2xl font-semibold tabular-nums tracking-display text-n-slate-12"
        >
          {{ metric.value }}
        </span>
        <span
          v-if="metric.change"
          class="truncate text-xs font-medium"
          :class="CHANGE_TONES[metric.changeTone]"
          :title="$t('HOME.V2.CHANGE.COMPARED', { days: period })"
        >
          {{ metric.change }}
        </span>
      </div>
    </div>
  </div>
</template>

<script setup>
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Sparkline from './Sparkline.vue';

// A number with its label, an optional change line and a small trend line.

defineProps({
  label: { type: String, required: true },
  value: { type: [String, Number], required: true },
  icon: { type: String, required: true },
  tone: { type: String, default: 'blue' },
  change: { type: String, default: '' },
  changeTone: { type: String, default: 'neutral' },
  points: { type: Array, default: () => [] },
  isLoading: { type: Boolean, default: false },
});

const TONES = {
  blue: { chip: 'bg-n-blue-3 text-n-blue-11', line: 'text-n-blue-9' },
  teal: { chip: 'bg-n-teal-3 text-n-teal-11', line: 'text-n-teal-9' },
  amber: { chip: 'bg-n-amber-3 text-n-amber-11', line: 'text-n-amber-9' },
  violet: { chip: 'bg-n-violet-3 text-n-violet-11', line: 'text-n-violet-9' },
};
const CHANGE_TONES = {
  good: 'text-n-teal-11',
  bad: 'text-n-ruby-11',
  neutral: 'text-n-slate-11',
};
</script>

<template>
  <div
    class="flex min-w-0 flex-col gap-4 rounded-card bg-n-solid-2 p-5 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
  >
    <div class="flex items-center gap-2.5">
      <span
        class="grid size-8 shrink-0 place-items-center rounded-lg"
        :class="TONES[tone].chip"
      >
        <Icon :icon="icon" class="size-4" />
      </span>
      <span class="truncate text-sm text-n-slate-11">{{ label }}</span>
    </div>
    <div class="flex items-end justify-between gap-3">
      <div class="flex min-w-0 flex-col gap-1">
        <span
          v-if="isLoading"
          class="h-9 w-16 animate-pulse rounded bg-n-alpha-2"
        />
        <span
          v-else
          class="font-display text-3xl font-semibold tabular-nums leading-9 tracking-display text-n-slate-12"
        >
          {{ value }}
        </span>
        <span v-if="change" class="text-xs" :class="CHANGE_TONES[changeTone]">
          {{ change }}
        </span>
      </div>
      <Sparkline
        v-if="points.length > 1"
        :points="points"
        class="h-10 w-24 shrink-0"
        :class="TONES[tone].line"
      />
    </div>
  </div>
</template>

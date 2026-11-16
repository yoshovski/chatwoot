<script setup>
import Icon from 'dashboard/components-next/icon/Icon.vue';

// A KPI metric tile: icon badge + label, tabular metric value, and optional comparison delta.
const props = defineProps({
  label: { type: String, required: true },
  value: { type: [String, Number], required: true },
  icon: { type: String, required: true },
  tone: { type: String, default: 'blue' },
  change: { type: String, default: '' },
  changeTone: { type: String, default: 'neutral' },
  hint: { type: String, default: '' },
  clickable: { type: Boolean, default: false },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['click']);

const TONES = {
  blue: { chip: 'bg-n-blue-3 text-n-blue-11' },
  teal: { chip: 'bg-n-teal-3 text-n-teal-11' },
  amber: { chip: 'bg-n-amber-3 text-n-amber-11' },
  violet: { chip: 'bg-n-violet-3 text-n-violet-11' },
};
const CHANGE_TONES = {
  good: 'text-n-teal-11',
  bad: 'text-n-ruby-11',
  neutral: 'text-n-slate-11',
};

const onActivate = () => {
  if (props.clickable) emit('click');
};
</script>

<template>
  <div
    class="flex min-w-0 flex-col gap-3 rounded-card bg-n-solid-2 p-4 shadow-card sm:gap-4 sm:p-5 outline outline-1 -outline-offset-1 outline-n-container"
    :class="
      clickable
        ? 'cursor-pointer transition-colors hover:bg-n-solid-1 focus-visible:outline-n-brand'
        : ''
    "
    :role="clickable ? 'button' : undefined"
    :tabindex="clickable ? 0 : undefined"
    @click="onActivate"
    @keydown.enter="onActivate"
    @keydown.space.prevent="onActivate"
  >
    <div
      class="flex flex-col items-start gap-2 sm:flex-row sm:items-center sm:gap-2.5"
    >
      <span
        class="grid size-8 shrink-0 place-items-center rounded-lg"
        :class="TONES[tone].chip"
      >
        <Icon :icon="icon" class="size-4" />
      </span>
      <span
        class="min-w-0 flex-1 text-sm leading-5 text-n-slate-11 sm:truncate"
      >
        {{ label }}
      </span>
      <span
        v-if="hint"
        v-tooltip.top="hint"
        class="hidden sm:inline-flex shrink-0 text-n-slate-9 hover:text-n-slate-11"
        :aria-label="hint"
      >
        <Icon icon="i-lucide-info" class="size-3.5" />
      </span>
    </div>
    <div class="flex flex-col gap-1">
      <span
        v-if="isLoading"
        class="h-9 w-16 animate-pulse rounded bg-n-alpha-2"
      />
      <span
        v-else
        class="font-display text-2xl font-semibold sm:text-3xl tabular-nums leading-9 tracking-display text-n-slate-12"
      >
        {{ value }}
      </span>
      <span
        v-if="change"
        class="text-xs font-medium"
        :class="CHANGE_TONES[changeTone]"
      >
        {{ change }}
      </span>
    </div>
  </div>
</template>

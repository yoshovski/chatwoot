<script setup>
import { ref, useId } from 'vue';
import SettingsHelp from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsHelp.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

// A KPI metric tile: icon badge + label, tabular metric value, and optional comparison delta.
defineProps({
  label: { type: String, required: true },
  value: { type: [String, Number], required: true },
  icon: { type: String, required: true },
  tone: { type: String, default: 'blue' },
  change: { type: String, default: '' },
  changeTone: { type: String, default: 'neutral' },
  hoverHint: Boolean,
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

const labelId = useId();
const valueId = useId();
const hintId = useId();
const showHint = ref(false);

const dismissHint = event => {
  if (!showHint.value) return;
  event.stopPropagation();
  event.preventDefault();
  showHint.value = false;
};
</script>

<template>
  <div
    class="relative min-w-0 rounded-card bg-n-solid-2 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
  >
    <button
      v-if="clickable"
      type="button"
      class="absolute inset-0 w-full rounded-card hover:bg-n-alpha-1 focus-visible:outline-n-brand"
      :aria-labelledby="isLoading ? labelId : `${labelId} ${valueId}`"
      @click="emit('click')"
    />
    <div class="flex min-w-0 flex-col gap-3 p-4 sm:gap-4 sm:p-5">
      <span
        class="flex flex-col items-start gap-2 sm:flex-row sm:items-center sm:gap-2.5"
        :class="{ 'pe-10 sm:pe-8': hint }"
      >
        <span
          class="grid size-8 shrink-0 place-items-center rounded-lg"
          :class="TONES[tone].chip"
        >
          <Icon :icon="icon" class="size-4" />
        </span>
        <span
          :id="labelId"
          class="min-w-0 break-words text-sm leading-5 text-n-slate-11"
        >
          {{ label }}
        </span>
      </span>
      <span class="flex flex-col gap-1">
        <span
          v-if="isLoading"
          class="h-9 w-16 animate-pulse rounded bg-n-alpha-2"
        />
        <span
          v-else
          :id="valueId"
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
      </span>
    </div>
    <div
      v-if="hint && hoverHint"
      class="absolute end-2 top-2 sm:end-3 sm:top-5"
    >
      <SettingsHelp :label="label" :text="hint" />
    </div>
    <template v-else-if="hint">
      <button
        type="button"
        class="absolute end-2 top-2 grid size-11 place-items-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2 focus-visible:outline-n-brand sm:end-3 sm:top-5 sm:size-8"
        :aria-label="$t('GENERAL.METRIC_HELP', { metric: label })"
        :aria-expanded="showHint"
        :aria-controls="hintId"
        @click="showHint = !showHint"
        @keydown.esc="dismissHint"
      >
        <Icon icon="i-lucide-info" class="size-4" />
      </button>
      <p
        v-show="showHint"
        :id="hintId"
        class="relative mx-4 mb-4 break-words rounded-lg bg-n-alpha-2 p-3 text-sm text-n-slate-12 sm:mx-5 sm:mb-5"
      >
        {{ hint }}
      </p>
    </template>
  </div>
</template>

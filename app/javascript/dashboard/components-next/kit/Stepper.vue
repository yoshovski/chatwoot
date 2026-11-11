<script setup>
import Icon from 'dashboard/components-next/icon/Icon.vue';

// A checklist of steps. Each step is done, skipped or open; open steps show their hint.
// The step's buttons go in the `actions` slot.
defineProps({
  steps: {
    type: Array,
    required: true,
    // [{ key, title, hint, state: 'done' | 'skipped' | 'open' }]
  },
});

const ICONS = {
  done: 'i-lucide-circle-check',
  skipped: 'i-lucide-circle-minus',
  open: 'i-lucide-circle-dashed',
};
</script>

<template>
  <ol class="m-0 flex list-none flex-col divide-y divide-n-weak p-0">
    <li
      v-for="step in steps"
      :key="step.key"
      class="flex items-center justify-between gap-3 py-2.5 first:pt-0 last:pb-0"
    >
      <div class="flex min-w-0 items-start gap-2.5">
        <Icon
          :icon="ICONS[step.state]"
          class="mt-0.5 size-4 shrink-0"
          :class="step.state === 'done' ? 'text-n-teal-10' : 'text-n-slate-10'"
        />
        <div class="flex min-w-0 flex-col">
          <span
            class="text-sm font-medium"
            :class="
              step.state === 'open' ? 'text-n-slate-12' : 'text-n-slate-11'
            "
          >
            {{ step.title }}
          </span>
          <span
            v-if="step.state === 'open' && step.hint"
            class="text-xs text-n-slate-11"
          >
            {{ step.hint }}
          </span>
        </div>
      </div>
      <div class="flex shrink-0 items-center gap-1">
        <slot name="actions" :step="step" />
      </div>
    </li>
  </ol>
</template>

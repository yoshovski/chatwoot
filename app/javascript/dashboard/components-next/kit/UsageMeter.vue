<script setup>
import { computed } from 'vue';

// How much of a limit is used. `limit: null` means there is no limit; the bar is hidden then.
// The caller formats `valueLabel` ("112 / 150") and `hint` in its own words.
const props = defineProps({
  label: { type: String, required: true },
  used: { type: Number, default: 0 },
  limit: { type: Number, default: null },
  valueLabel: { type: String, default: '' },
  hint: { type: String, default: '' },
});

const WARN_AT = 90;

const hasLimit = computed(() => props.limit !== null);
const percent = computed(() => {
  if (!hasLimit.value) return 0;
  if (props.limit === 0) return 100;
  return Math.min(100, Math.round((props.used / props.limit) * 100));
});
const barClass = computed(() =>
  percent.value >= WARN_AT ? 'bg-n-ruby-9' : 'bg-n-brand'
);
</script>

<template>
  <div class="flex min-w-0 flex-col gap-1.5">
    <div class="flex items-baseline justify-between gap-2">
      <span class="truncate text-xs text-n-slate-11">{{ label }}</span>
      <span class="shrink-0 text-xs tabular-nums text-n-slate-12">
        {{ valueLabel || used }}
      </span>
    </div>
    <div
      v-if="hasLimit"
      class="h-1.5 w-full overflow-hidden rounded-full bg-n-alpha-2"
      role="progressbar"
      :aria-valuenow="percent"
      aria-valuemin="0"
      aria-valuemax="100"
      :aria-label="label"
    >
      <div
        class="h-full rounded-full transition-all duration-300"
        :class="barClass"
        :style="{ width: `${percent}%` }"
      />
    </div>
    <span v-if="hint" class="text-xs text-n-slate-10">{{ hint }}</span>
  </div>
</template>

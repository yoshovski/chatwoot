<script setup>
import { computed } from 'vue';

const props = defineProps({
  label: { type: String, required: true },
  used: { type: Number, default: 0 },
  // null means no limit was set in Super Admin; 0 is a real limit.
  limit: { type: Number, default: null },
  hint: { type: String, default: '' },
});

const hasLimit = computed(() => props.limit !== null);
const percent = computed(() => {
  if (!hasLimit.value) return 0;
  if (props.limit === 0) return 100;
  return Math.min(100, Math.round((props.used / props.limit) * 100));
});
const barClass = computed(() =>
  percent.value >= 90 ? 'bg-n-ruby-9' : 'bg-n-brand'
);
</script>

<template>
  <div class="flex min-w-0 flex-col gap-1.5">
    <div class="flex items-baseline justify-between gap-2">
      <span class="truncate text-xs text-n-slate-11">{{ label }}</span>
      <span class="shrink-0 text-xs tabular-nums text-n-slate-12">
        <template v-if="hasLimit">
          {{ $t('HOME.USAGE.OF_LIMIT', { used, limit }) }}
        </template>
        <template v-else>{{ used }}</template>
      </span>
    </div>
    <div
      v-if="hasLimit"
      class="h-1.5 w-full overflow-hidden rounded-full bg-n-alpha-2"
    >
      <div
        class="h-full rounded-full transition-all duration-300"
        :class="barClass"
        :style="{ width: `${percent}%` }"
      />
    </div>
    <span class="text-xs text-n-slate-10">
      {{ hasLimit ? hint : $t('HOME.USAGE.NO_LIMIT_SET') }}
    </span>
  </div>
</template>

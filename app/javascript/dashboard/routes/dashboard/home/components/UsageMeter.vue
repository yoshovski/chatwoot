<script setup>
import { computed } from 'vue';

const props = defineProps({
  label: { type: String, required: true },
  used: { type: Number, default: 0 },
  limit: { type: Number, default: null },
});

const percent = computed(() =>
  props.limit ? Math.min(100, Math.round((props.used / props.limit) * 100)) : 0
);
const barClass = computed(() =>
  percent.value >= 90 ? 'bg-n-ruby-9' : 'bg-n-brand'
);
</script>

<template>
  <div class="flex min-w-0 flex-col gap-1.5">
    <div class="flex items-baseline justify-between gap-2">
      <span class="truncate text-xs text-n-slate-11">{{ label }}</span>
      <span class="shrink-0 text-xs tabular-nums text-n-slate-12">
        <template v-if="limit">
          {{ $t('HOME.USAGE.OF_LIMIT', { used, limit }) }}
        </template>
        <template v-else>{{ used }}</template>
      </span>
    </div>
    <div class="h-1.5 w-full overflow-hidden rounded-full bg-n-alpha-2">
      <div
        v-if="limit"
        class="h-full rounded-full transition-all duration-300"
        :class="barClass"
        :style="{ width: `${percent}%` }"
      />
    </div>
    <span v-if="!limit" class="text-xs text-n-slate-10">
      {{ $t('HOME.USAGE.NO_LIMIT') }}
    </span>
  </div>
</template>

<script setup>
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  label: { type: String, required: true },
  value: { type: [String, Number], required: true },
  icon: { type: String, default: '' },
  to: { type: [Object, String], default: null },
  isLoading: { type: Boolean, default: false },
});
</script>

<template>
  <component
    :is="to ? 'router-link' : 'div'"
    :to="to"
    class="flex min-w-0 flex-col gap-1 rounded-lg bg-n-alpha-1 px-3 py-2.5 transition-colors"
    :class="{ 'hover:bg-n-alpha-2': to }"
  >
    <span class="flex items-center gap-1.5 text-xs text-n-slate-11">
      <Icon v-if="icon" :icon="icon" class="size-3.5 shrink-0" />
      <span class="truncate">{{ label }}</span>
    </span>
    <span
      v-if="isLoading"
      class="my-1 h-5 w-10 animate-pulse rounded bg-n-alpha-2"
    />
    <span
      v-else
      class="text-xl font-semibold tabular-nums leading-7 text-n-slate-12"
    >
      {{ value }}
    </span>
  </component>
</template>

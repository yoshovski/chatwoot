<script setup>
import { computed } from 'vue';

const props = defineProps({
  label: { type: String, required: true },
  state: {
    type: String,
    required: true,
    validator: value => ['done', 'pending', 'missing'].includes(value),
  },
  stateLabel: { type: String, required: true },
  to: { type: [Object, String], default: null },
});

const dotClass = computed(
  () =>
    ({
      done: 'bg-n-teal-9',
      pending: 'bg-n-amber-9',
      missing: 'bg-n-slate-8',
    })[props.state]
);
</script>

<template>
  <li class="flex items-center justify-between gap-3 py-2 first:pt-0 last:pb-0">
    <span class="flex min-w-0 items-center gap-2.5 text-sm text-n-slate-12">
      <span class="size-2 shrink-0 rounded-full" :class="dotClass" />
      <span class="truncate">{{ label }}</span>
    </span>
    <router-link
      v-if="to && state !== 'done'"
      :to="to"
      class="shrink-0 text-xs font-medium text-n-blue-11 hover:underline"
    >
      {{ stateLabel }}
    </router-link>
    <span v-else class="shrink-0 text-xs text-n-slate-11">
      {{ stateLabel }}
    </span>
  </li>
</template>

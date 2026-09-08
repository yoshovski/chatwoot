<script setup>
import { computed } from 'vue';

const props = defineProps({
  starters: { type: Array, default: () => [] },
});

const emit = defineEmits(['select']);

const activeStarters = computed(() =>
  props.starters.filter(starter => starter.enabled !== false && starter.title)
);
</script>

<template>
  <div
    v-show="activeStarters.length"
    class="flex flex-col overflow-hidden rounded-2xl bg-n-background shadow-sm outline outline-1 outline-n-container dark:bg-n-solid-2"
  >
    <button
      v-for="starter in activeStarters"
      :key="starter.id"
      type="button"
      class="flex w-full items-center justify-between gap-3 px-4 py-4 text-start text-sm font-medium text-n-slate-12 transition-colors hover:bg-n-alpha-2 [&:not(:last-child)]:border-b [&:not(:last-child)]:border-n-weak"
      @click="emit('select', starter.title)"
    >
      <span>{{ starter.title }}</span>
      <i class="i-lucide-chevron-right size-4 shrink-0 rtl:rotate-180" />
    </button>
  </div>
</template>

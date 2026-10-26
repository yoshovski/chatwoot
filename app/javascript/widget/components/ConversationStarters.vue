<script setup>
import { computed } from 'vue';

const props = defineProps({
  starters: { type: Array, default: () => [] },
});

const emit = defineEmits(['select']);

const activeStarters = computed(() =>
  props.starters.filter(starter => starter.enabled !== false && starter.title)
);

const onSelect = starter => {
  if (starter.action_type === 'url' && starter.target) {
    window.open(starter.target, '_blank', 'noopener,noreferrer');
    return;
  }
  emit('select', starter);
};
</script>

<template>
  <div
    v-show="activeStarters.length"
    class="mb-3 flex flex-col overflow-hidden rounded-2xl bg-n-background shadow-sm outline outline-1 outline-n-container dark:bg-n-solid-2"
  >
    <button
      v-for="starter in activeStarters"
      :key="starter.id"
      type="button"
      class="flex w-full items-center justify-between gap-3 px-4 py-4 text-start text-sm font-medium text-n-slate-12 transition-colors hover:bg-n-alpha-2 [&:not(:last-child)]:border-b [&:not(:last-child)]:border-n-weak"
      @click="onSelect(starter)"
    >
      <span>{{ starter.title }}</span>
      <i
        :class="
          starter.action_type === 'url'
            ? 'i-lucide-external-link size-4 shrink-0'
            : 'i-lucide-chevron-right size-4 shrink-0 rtl:rotate-180'
        "
      />
    </button>
  </div>
</template>

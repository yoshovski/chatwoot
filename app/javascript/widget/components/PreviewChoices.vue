<script setup>
// Quiet text rows under the message in the closed-chat card; the arrow in the widget colour shows on hover.
defineProps({
  choices: { type: Array, default: () => [] },
  disabled: { type: Boolean, default: false },
});
const emit = defineEmits(['choose']);
</script>

<template>
  <div class="border-0 border-t border-solid border-n-weak px-2 py-2">
    <button
      v-for="choice in choices"
      :key="choice.id || choice.value || choice.title"
      type="button"
      class="group/row flex w-full items-center justify-between gap-3 rounded-xl px-3 py-2.5 text-start text-[0.9375rem] text-n-slate-12 transition-colors hover:bg-n-alpha-1 disabled:opacity-50"
      :disabled="disabled"
      @click="emit('choose', choice)"
    >
      <span class="min-w-0">{{ choice.title }}</span>
      <i
        class="i-lucide-arrow-right size-4 shrink-0 text-[var(--widget-color)] opacity-0 transition-opacity group-hover/row:opacity-100 group-focus-visible/row:opacity-100 rtl:rotate-180"
      />
    </button>
    <slot />
  </div>
</template>

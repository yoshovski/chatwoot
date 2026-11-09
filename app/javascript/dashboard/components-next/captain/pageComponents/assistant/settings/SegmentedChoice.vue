<script setup>
// Compact radio group for a primary choice with a few presets.
defineProps({
  label: { type: String, required: true },
  options: { type: Array, required: true },
});

const model = defineModel({ type: String, default: '' });
</script>

<template>
  <div
    class="flex flex-wrap gap-1 p-1 rounded-lg bg-n-alpha-1"
    role="radiogroup"
    :aria-label="label"
  >
    <button
      v-for="option in options"
      :key="option.id"
      type="button"
      role="radio"
      :aria-checked="model === option.id"
      class="flex items-center justify-center flex-1 gap-1.5 px-3 py-1.5 text-sm font-medium whitespace-nowrap transition-colors rounded-md min-w-24 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
      :class="
        model === option.id
          ? 'bg-n-solid-active text-n-slate-12 shadow-sm outline outline-1 outline-n-container'
          : 'text-n-slate-11 hover:text-n-slate-12'
      "
      @click="model = option.id"
    >
      <span v-if="option.icon" :class="option.icon" class="size-4" />
      {{ option.label }}
    </button>
  </div>
</template>

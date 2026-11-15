<script setup>
import Icon from 'dashboard/components-next/icon/Icon.vue';

// The one search input: a magnifier, the text and nothing else. `large` is the settings home's field.
defineProps({
  placeholder: { type: String, required: true },
  large: { type: Boolean, default: false },
});

const query = defineModel({ type: String, default: '' });
</script>

<template>
  <label
    class="flex min-w-0 items-center gap-2"
    :class="
      large
        ? 'h-12 gap-3 rounded-card bg-n-solid-2 px-4 shadow-card outline outline-1 -outline-offset-1 outline-n-container focus-within:outline-n-brand'
        : 'h-9 rounded-lg bg-n-alpha-1 px-3 focus-within:outline focus-within:outline-1 focus-within:outline-n-brand'
    "
  >
    <Icon
      icon="i-lucide-search"
      class="shrink-0 text-n-slate-10"
      :class="large ? 'size-5' : 'size-4'"
    />
    <input
      v-model="query"
      type="search"
      :aria-label="placeholder"
      :placeholder="placeholder"
      class="!mb-0 h-full min-w-0 flex-1 !border-0 !bg-transparent !p-0 text-n-slate-12 !shadow-none !outline-none placeholder:text-n-slate-10"
      :class="large ? 'text-base' : 'text-sm'"
    />
  </label>
</template>

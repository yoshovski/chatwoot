<script setup>
import Icon from 'dashboard/components-next/icon/Icon.vue';

// Nothing to show yet, or something went wrong (`tone="error"`). The action goes in the default slot.
defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
  icon: { type: String, default: 'i-lucide-inbox' },
  tone: {
    type: String,
    default: 'neutral',
    validator: value => ['neutral', 'success', 'error'].includes(value),
  },
});

const TONES = {
  neutral: 'bg-n-alpha-2 text-n-slate-11',
  success: 'bg-n-teal-3 text-n-teal-11',
  error: 'bg-n-ruby-3 text-n-ruby-11',
};
</script>

<template>
  <div
    class="flex flex-col items-center gap-3 px-4 py-6 text-center"
    :role="tone === 'error' ? 'alert' : undefined"
  >
    <span
      class="grid size-10 place-items-center rounded-full"
      :class="TONES[tone]"
    >
      <Icon :icon="icon" class="size-5" />
    </span>
    <div class="flex flex-col gap-1">
      <p class="mb-0 text-sm font-medium text-n-slate-12">{{ title }}</p>
      <p v-if="description" class="mb-0 text-sm text-n-slate-11">
        {{ description }}
      </p>
    </div>
    <slot />
  </div>
</template>

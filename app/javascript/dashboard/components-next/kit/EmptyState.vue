<script setup>
import { computed } from 'vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
  icon: { type: String, default: '' },
  state: {
    type: String,
    default: '',
    validator: value =>
      ['', 'first-use', 'filtered', 'unavailable', 'error'].includes(value),
  },
  tone: {
    type: String,
    default: 'neutral',
    validator: value => ['neutral', 'success', 'error'].includes(value),
  },
});

const STATE_ICONS = {
  'first-use': 'i-lucide-inbox',
  filtered: 'i-lucide-search',
  unavailable: 'i-lucide-lock',
  error: 'i-lucide-triangle-alert',
};
const effectiveTone = computed(() => {
  if (props.state === 'error') return 'error';
  return props.state ? 'neutral' : props.tone;
});
const effectiveIcon = computed(
  () => props.icon || STATE_ICONS[props.state] || STATE_ICONS['first-use']
);

const TONES = {
  neutral: 'bg-n-alpha-2 text-n-slate-11',
  success: 'bg-n-teal-3 text-n-teal-11',
  error: 'bg-n-ruby-3 text-n-ruby-11',
};
</script>

<template>
  <div
    class="flex flex-col items-center gap-3 px-4 py-6 text-center"
    :role="effectiveTone === 'error' ? 'alert' : undefined"
  >
    <span
      class="grid size-10 place-items-center rounded-full"
      :class="TONES[effectiveTone]"
    >
      <Icon :icon="effectiveIcon" aria-hidden="true" class="size-5" />
    </span>
    <div class="flex min-w-0 flex-col gap-1 break-words">
      <p class="mb-0 text-sm font-medium text-n-slate-12">{{ title }}</p>
      <p v-if="description" class="mb-0 text-sm text-n-slate-11">
        {{ description }}
      </p>
    </div>
    <div
      v-if="$slots.default || $slots.secondary"
      class="flex flex-wrap items-center justify-center gap-2"
    >
      <slot />
      <slot name="secondary" />
    </div>
    <div v-if="$slots.decorative" inert aria-hidden="true" class="max-w-full">
      <slot name="decorative" />
    </div>
  </div>
</template>

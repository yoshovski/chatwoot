<script setup>
import { computed } from 'vue';

// The one way to show an agent's or a channel's state. `inverted` is for the gradient band.
const props = defineProps({
  status: {
    type: String,
    required: true,
    validator: value =>
      ['live', 'learning', 'paused', 'limit', 'attention'].includes(value),
  },
  label: { type: String, required: true },
  inverted: { type: Boolean, default: false },
});

const TONES = {
  live: { pill: 'bg-n-teal-3 text-n-teal-11', dot: 'bg-n-teal-9' },
  learning: { pill: 'bg-n-blue-3 text-n-blue-11', dot: 'bg-n-blue-9' },
  paused: { pill: 'bg-n-alpha-2 text-n-slate-11', dot: 'bg-n-slate-9' },
  limit: { pill: 'bg-n-ruby-3 text-n-ruby-11', dot: 'bg-n-ruby-9' },
  attention: { pill: 'bg-n-amber-3 text-n-amber-11', dot: 'bg-n-amber-9' },
};
const tone = computed(() => TONES[props.status]);
</script>

<template>
  <span
    class="inline-flex items-center gap-2 rounded-full px-3 py-1 text-sm font-medium"
    :class="inverted ? 'bg-n-black/20 text-white' : tone.pill"
  >
    <span class="size-2 shrink-0 rounded-full" :class="tone.dot" />
    {{ label }}
  </span>
</template>

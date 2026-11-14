<script setup>
import { toRef } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { useBillingView } from '../useBillingView';

// The one alert at the top of Billing; the cards below never repeat it.
const props = defineProps({
  billing: { type: Object, required: true },
  busy: { type: Boolean, default: false },
});
const emit = defineEmits(['action']);
const { alert } = useBillingView(toRef(props, 'billing'));

const TONES = {
  amber: 'bg-n-amber-3 text-n-amber-11',
  ruby: 'bg-n-ruby-3 text-n-ruby-11',
  slate: 'bg-n-alpha-2 text-n-slate-12',
};
</script>

<template>
  <div
    v-if="alert"
    class="flex flex-wrap items-center gap-x-3 gap-y-2 rounded-card px-4 py-3"
    :class="TONES[alert.tone]"
    role="alert"
  >
    <span :class="alert.icon" class="size-4 shrink-0" aria-hidden="true" />
    <p class="mb-0 min-w-0 flex-1 basis-64 text-sm font-medium">
      {{ alert.text }}
    </p>
    <Button
      v-if="alert.action"
      :label="alert.label"
      size="sm"
      :color="alert.tone === 'ruby' ? 'ruby' : 'blue'"
      :is-loading="busy"
      :disabled="busy"
      @click="emit('action', alert.action)"
    />
  </div>
</template>

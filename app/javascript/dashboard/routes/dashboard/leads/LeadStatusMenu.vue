<script setup>
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys -- Keys share a fixed namespace and come from the lead settings or status list. */
import { useI18n } from 'vue-i18n';
import { STATUSES, STATUS_TONES } from './leadsView';

// The lead's status as a pill that changes it in place.
defineProps({
  status: { type: String, required: true },
  disabled: { type: Boolean, default: false },
});
const emit = defineEmits(['change']);
const { t } = useI18n();
</script>

<template>
  <div class="relative inline-flex">
    <select
      :key="`${status}-${disabled}`"
      :value="status"
      :disabled="disabled"
      :aria-label="t('LEADS.COLUMNS.STATUS')"
      class="m-0 !h-7 w-[7.5rem] cursor-pointer appearance-none rounded-full border-0 bg-none py-0 pe-7 ps-6 text-xs font-medium"
      :class="STATUS_TONES[status].pill"
      @keydown.stop
      @click.stop
      @change="emit('change', $event.target.value)"
    >
      <option v-for="option in STATUSES" :key="option" :value="option">
        {{ t(`LEADS.STATUS.${option.toUpperCase()}`) }}
      </option>
    </select>
    <span
      class="pointer-events-none absolute start-2.5 top-1/2 size-1.5 -translate-y-1/2 rounded-full"
      :class="STATUS_TONES[status].dot"
      aria-hidden="true"
    />
    <span
      class="i-lucide-chevron-down pointer-events-none absolute end-2 top-1/2 size-3.5 -translate-y-1/2 opacity-70"
      aria-hidden="true"
    />
  </div>
</template>

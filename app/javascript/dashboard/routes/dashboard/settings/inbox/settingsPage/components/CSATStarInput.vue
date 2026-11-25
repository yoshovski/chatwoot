<script setup>
import { CSAT_DISPLAY_TYPES } from 'shared/constants/messages';
import { computed } from 'vue';

const props = defineProps({
  selected: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update']);

const selectionClass = computed(() => {
  return props.selected
    ? 'bg-n-brand/5 outline-n-brand'
    : 'bg-n-alpha-black2 outline-n-weak';
});
</script>

<template>
  <button
    type="button"
    :aria-pressed="selected"
    class="flex flex-col items-center rounded-lg transition-all duration-300 cursor-pointer outline outline-1 px-2 py-2.5 gap-2 min-w-0 w-full justify-center"
    :class="selectionClass"
    @click="emit('update', CSAT_DISPLAY_TYPES.STAR)"
  >
    <span class="flex items-center justify-center" aria-hidden="true">
      <div
        v-for="n in 5"
        :key="'star-' + n"
        class="rounded-full p-1 transition-transform duration-150 focus:outline-none flex items-center flex-shrink-0"
      >
        <i class="i-ri-star-fill text-n-amber-9 text-2xl" />
      </div>
    </span>
    <span class="text-sm font-medium text-n-slate-12">{{
      $t('INBOX_MGMT.WEBSITE_SETTINGS.RATING_STARS')
    }}</span>
  </button>
</template>

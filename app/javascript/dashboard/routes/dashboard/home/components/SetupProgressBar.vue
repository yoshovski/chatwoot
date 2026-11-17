<script setup>
import { computed } from 'vue';

const props = defineProps({
  done: { type: Number, required: true },
  total: { type: Number, required: true },
});
const percent = computed(() => Math.round((props.done / props.total) * 100));
</script>

<template>
  <div
    class="h-1.5 overflow-hidden rounded-full bg-n-alpha-3"
    role="progressbar"
    :aria-label="$t('HOME.GETTING_STARTED.TITLE')"
    :aria-valuenow="done"
    :aria-valuemax="total"
    aria-valuemin="0"
  >
    <div
      class="h-full rounded-full bg-n-brand"
      :style="{ width: `${percent}%` }"
    />
  </div>
</template>

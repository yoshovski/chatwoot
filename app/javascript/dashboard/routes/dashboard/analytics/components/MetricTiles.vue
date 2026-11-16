<script setup>
import MetricTile from 'dashboard/components-next/kit/MetricTile.vue';
import CardError from '../../home/components/CardError.vue';

// The four numbers on top of every Analytics view, each against the period before.
defineProps({
  // [{ key, label, value, icon, tone, change, changeTone }]
  tiles: { type: Array, required: true },
  isLoading: { type: Boolean, default: false },
  hasPartialError: { type: Boolean, default: false },
  hasError: { type: Boolean, default: false },
});
const emit = defineEmits(['retry']);
</script>

<template>
  <div v-if="hasPartialError" role="status" class="text-sm text-n-amber-11">
    {{ $t('ANALYTICS.PARTIAL_ERROR') }}
    <button type="button" class="underline" @click="emit('retry')">
      {{ $t('ANALYTICS.RETRY') }}
    </button>
  </div>
  <div
    v-if="hasError"
    class="rounded-card bg-n-solid-2 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
  >
    <CardError @retry="emit('retry')" />
  </div>
  <div v-else class="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-4">
    <div v-for="tile in tiles" :key="tile.key" class="flex min-w-0 flex-col">
      <MetricTile
        class="flex-1"
        :label="tile.label"
        :value="tile.value"
        :icon="tile.icon"
        :tone="tile.tone"
        :change="tile.change"
        :change-tone="tile.changeTone"
        :is-loading="isLoading"
      />
      <details v-if="tile.hint" class="mt-2 px-1 text-xs text-n-slate-11">
        <summary
          class="cursor-pointer rounded py-2 focus-visible:outline focus-visible:outline-n-brand"
        >
          {{ $t('ANALYTICS.METRIC_DEFINITION', { metric: tile.label }) }}
        </summary>
        <p class="mb-0 py-2">{{ tile.hint }}</p>
      </details>
    </div>
  </div>
</template>

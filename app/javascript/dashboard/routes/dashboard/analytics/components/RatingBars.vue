<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import EmptyState from 'dashboard/components-next/kit/EmptyState.vue';
import CardError from '../../home/components/CardError.vue';

// Ratings 5 to 1, each with its count and share as a bar, readable as a list without the bars.
const props = defineProps({
  // [{ rating, count, share }]
  rows: { type: Array, default: () => [] },
  isLoading: { type: Boolean, default: false },
  hasError: { type: Boolean, default: false },
});
const emit = defineEmits(['retry']);
const { t } = useI18n();

const BARS = {
  5: 'bg-n-teal-9',
  4: 'bg-n-teal-8',
  3: 'bg-n-amber-8',
  2: 'bg-n-ruby-8',
  1: 'bg-n-ruby-9',
};
const isEmpty = computed(() => props.rows.every(row => !row.count));
</script>

<template>
  <div v-if="isLoading" class="flex flex-col gap-3" aria-busy="true">
    <span
      v-for="n in 5"
      :key="n"
      class="h-6 w-full animate-pulse rounded bg-n-alpha-2"
    />
  </div>
  <CardError v-else-if="hasError" @retry="emit('retry')" />
  <EmptyState
    v-else-if="isEmpty"
    icon="i-lucide-star"
    :title="t('ANALYTICS.RATING.EMPTY')"
  />
  <ol v-else class="m-0 flex list-none flex-col gap-3 p-0">
    <li
      v-for="row in rows"
      :key="row.rating"
      class="grid grid-cols-[4.5rem_1fr_5.5rem] items-center gap-3 text-sm"
    >
      <span class="inline-flex items-center gap-1 text-n-slate-12">
        <span
          class="i-lucide-star size-3.5 text-n-amber-9"
          aria-hidden="true"
        />
        {{ t('ANALYTICS.RATING.STARS', { rating: row.rating }, row.rating) }}
      </span>
      <span
        class="h-2 w-full overflow-hidden rounded-full bg-n-alpha-2"
        aria-hidden="true"
      >
        <span
          class="block h-full rounded-full"
          :class="BARS[row.rating]"
          :style="{ width: `${row.share}%` }"
        />
      </span>
      <span class="text-end tabular-nums text-n-slate-11">
        {{
          t('ANALYTICS.RATING.COUNT', { count: row.count, share: row.share })
        }}
      </span>
    </li>
  </ol>
</template>

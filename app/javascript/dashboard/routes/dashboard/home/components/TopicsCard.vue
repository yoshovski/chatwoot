<script setup>
import { computed } from 'vue';
import EmptyState from 'dashboard/components-next/kit/EmptyState.vue';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';
import CardError from './CardError.vue';

// What customers asked about most, as a ranked list with a share bar.
const props = defineProps({
  // [{ label, count }]
  topics: { type: Array, default: () => [] },
  isLoading: { type: Boolean, default: false },
  hasError: { type: Boolean, default: false },
});

const emit = defineEmits(['retry']);

const humanize = label => {
  const words = label.replace(/[-_]+/g, ' ');
  return words.charAt(0).toUpperCase() + words.slice(1);
};

const rows = computed(() => {
  const max = Math.max(...props.topics.map(topic => topic.count), 1);
  return props.topics.map(topic => ({
    ...topic,
    // Labels are slugs ("sizing-and-fit"); show them as words.
    name: humanize(topic.label),
    width: `${Math.round((topic.count / max) * 100)}%`,
  }));
});
</script>

<template>
  <SectionCard :title="$t('HOME.V2.TOPICS.TITLE')">
    <div v-if="isLoading" class="flex flex-col gap-3" aria-busy="true">
      <span
        v-for="n in 4"
        :key="n"
        class="h-6 w-full animate-pulse rounded bg-n-alpha-2"
      />
    </div>
    <CardError v-else-if="hasError" @retry="emit('retry')" />
    <EmptyState
      v-else-if="!rows.length"
      icon="i-lucide-tags"
      :title="$t('HOME.V2.TOPICS.EMPTY')"
    />
    <ol v-else class="m-0 flex list-none flex-col gap-3 p-0">
      <li v-for="topic in rows" :key="topic.label" class="flex flex-col gap-1">
        <div class="flex items-center justify-between gap-3 text-sm">
          <span class="truncate text-n-slate-12">{{ topic.name }}</span>
          <span class="shrink-0 tabular-nums text-n-slate-11">
            {{ topic.count }}
          </span>
        </div>
        <span class="h-1.5 w-full overflow-hidden rounded-full bg-n-alpha-2">
          <span
            class="block h-full rounded-full bg-n-blue-9"
            :style="{ width: topic.width }"
          />
        </span>
      </li>
    </ol>
  </SectionCard>
</template>

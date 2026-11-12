<script setup>
import EmptyState from 'dashboard/components-next/kit/EmptyState.vue';
import ListRow from 'dashboard/components-next/kit/ListRow.vue';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';
import CardError from './CardError.vue';

// "Needs you": named items (homeView.needItems), one button each. Waiting customers get the primary button.
defineProps({
  // [{ key, title, hint, action, to }]
  items: { type: Array, default: () => [] },
  isLoading: { type: Boolean, default: false },
  hasError: { type: Boolean, default: false },
});

const emit = defineEmits(['action', 'retry']);

const TONES = {
  handoff: 'amber',
  gap: 'teal',
  failed_action: 'ruby',
  failed_sync: 'ruby',
  channel: 'ruby',
};
</script>

<template>
  <SectionCard
    :title="
      items.length && !isLoading && !hasError
        ? $t('HOME.V2.NEEDS.TITLE_COUNT', { count: items.length })
        : $t('HOME.V2.NEEDS.TITLE')
    "
  >
    <div v-if="isLoading" class="flex flex-col gap-3" aria-busy="true">
      <span
        v-for="n in 3"
        :key="n"
        class="h-10 w-full animate-pulse rounded bg-n-alpha-2"
      />
    </div>
    <CardError v-else-if="hasError" @retry="emit('retry')" />
    <ul
      v-else-if="items.length"
      class="m-0 flex list-none flex-col divide-y divide-n-weak p-0"
    >
      <ListRow
        v-for="(item, index) in items"
        :key="`${item.key}-${index}`"
        :title="item.title"
        :hint="item.hint"
        :tone="TONES[item.key]"
        :action-label="item.action"
        :primary="item.key === 'handoff'"
        @action="emit('action', item)"
      />
    </ul>
    <EmptyState
      v-else
      tone="success"
      icon="i-lucide-circle-check-big"
      :title="$t('HOME.V2.NEEDS.EMPTY')"
    />
  </SectionCard>
</template>

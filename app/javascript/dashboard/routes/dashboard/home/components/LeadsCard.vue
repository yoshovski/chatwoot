<script setup>
import { dynamicTime } from 'shared/helpers/timeHelper';
import EmptyState from 'dashboard/components-next/kit/EmptyState.vue';
import ListRow from 'dashboard/components-next/kit/ListRow.vue';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';
import CardError from './CardError.vue';

// The most recent conversations where the AI agent collected a lead.
defineProps({
  // [{ id, name, at }]
  leads: { type: Array, default: () => [] },
  isLoading: { type: Boolean, default: false },
  hasError: { type: Boolean, default: false },
});

const emit = defineEmits(['open', 'retry']);
</script>

<template>
  <SectionCard :title="$t('HOME.V2.LEADS.TITLE')">
    <div v-if="isLoading" class="flex flex-col gap-3" aria-busy="true">
      <span
        v-for="n in 2"
        :key="n"
        class="h-10 w-full animate-pulse rounded bg-n-alpha-2"
      />
    </div>
    <CardError v-else-if="hasError" @retry="emit('retry')" />
    <ul
      v-else-if="leads.length"
      class="m-0 flex list-none flex-col divide-y divide-n-weak p-0"
    >
      <ListRow
        v-for="lead in leads"
        :key="lead.id"
        :title="lead.name || $t('HOME.V2.NEEDS.SOMEONE')"
        :hint="dynamicTime(lead.at)"
        tone="blue"
        :action-label="$t('HOME.V2.LEADS.OPEN')"
        @action="emit('open', lead)"
      />
    </ul>
    <EmptyState
      v-else
      icon="i-lucide-user-round-plus"
      :title="$t('HOME.V2.LEADS.EMPTY')"
    />
  </SectionCard>
</template>

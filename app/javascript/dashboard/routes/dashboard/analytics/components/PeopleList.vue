<script setup>
import { useI18n } from 'vue-i18n';
import EmptyState from 'dashboard/components-next/kit/EmptyState.vue';
import { durationText } from '../analyticsView';

// The busiest people or teams in the period: conversations and time to first reply.
defineProps({
  // [{ id, name, conversations, firstReply }]
  rows: { type: Array, default: () => [] },
  emptyText: { type: String, required: true },
  limit: { type: Number, default: 4 },
  isLoading: { type: Boolean, default: false },
});
const { t } = useI18n();
</script>

<template>
  <div v-if="isLoading" class="flex flex-col gap-3" aria-busy="true">
    <span
      v-for="n in 3"
      :key="n"
      class="h-8 w-full animate-pulse rounded bg-n-alpha-2"
    />
  </div>
  <EmptyState
    v-else-if="!rows.length"
    icon="i-lucide-users"
    :title="emptyText"
  />
  <ul v-else class="m-0 flex list-none flex-col divide-y divide-n-weak p-0">
    <li
      v-for="person in rows.slice(0, limit)"
      :key="person.id"
      class="flex items-center gap-3 py-2.5 first:pt-0 last:pb-0"
    >
      <span class="me-auto truncate text-sm font-medium text-n-slate-12">
        {{ person.name }}
      </span>
      <span class="shrink-0 text-xs tabular-nums text-n-slate-11">
        {{
          t('ANALYTICS.PEOPLE.ROW', {
            conversations: person.conversations,
            time: durationText(person.firstReply, t),
          })
        }}
      </span>
    </li>
  </ul>
</template>

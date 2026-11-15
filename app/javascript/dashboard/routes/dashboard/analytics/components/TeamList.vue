<script setup>
import { useI18n } from 'vue-i18n';
import EmptyState from 'dashboard/components-next/kit/EmptyState.vue';
import { durationText } from '../analyticsView';

// The busiest people in the period: conversations, solved and time to first reply.
defineProps({
  team: { type: Array, default: () => [] },
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
    v-else-if="!team.length"
    icon="i-lucide-users"
    :title="t('ANALYTICS.TEAM_LIST.EMPTY')"
  />
  <ul v-else class="m-0 flex list-none flex-col divide-y divide-n-weak p-0">
    <li
      v-for="person in team.slice(0, limit)"
      :key="person.id"
      class="flex items-center gap-3 py-2.5 first:pt-0 last:pb-0"
    >
      <span class="me-auto truncate text-sm font-medium text-n-slate-12">
        {{ person.name }}
      </span>
      <span class="shrink-0 text-xs tabular-nums text-n-slate-11">
        {{
          t('ANALYTICS.TEAM_LIST.ROW', {
            conversations: person.conversations,
            time: durationText(person.firstReply, t),
          })
        }}
      </span>
    </li>
  </ul>
</template>

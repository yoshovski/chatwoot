<script setup>
import { useI18n } from 'vue-i18n';
import { RouterLink } from 'vue-router';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import EmptyState from 'dashboard/components-next/kit/EmptyState.vue';
import CardError from '../../home/components/CardError.vue';

// Each AI agent with the conversations it handled and how many it solved; a row opens the agent's own Overview.
defineProps({
  // [{ id, name, metrics: { conversations_handled: { current }, auto_resolution_rate: { current } } }]
  agents: { type: Array, default: () => [] },
  isLoading: { type: Boolean, default: false },
  hasError: { type: Boolean, default: false },
});
const emit = defineEmits(['retry']);
const { t } = useI18n();
</script>

<template>
  <div v-if="isLoading" class="flex flex-col gap-3" aria-busy="true">
    <span
      v-for="n in 2"
      :key="n"
      class="h-10 w-full animate-pulse rounded bg-n-alpha-2"
    />
  </div>
  <CardError v-else-if="hasError" @retry="emit('retry')" />
  <EmptyState
    v-else-if="!agents.length"
    icon="i-lucide-bot"
    :title="t('ANALYTICS.AI.NO_AGENTS')"
  />
  <ul v-else class="m-0 flex list-none flex-col divide-y divide-n-weak p-0">
    <li v-for="agent in agents" :key="agent.id">
      <RouterLink
        :to="{
          name: 'captain_assistants_overview_index',
          params: { assistantId: agent.id },
        }"
        class="group flex items-center gap-3 py-2.5"
      >
        <span
          class="grid size-8 shrink-0 place-items-center rounded-lg bg-n-blue-3 text-n-blue-11"
        >
          <Icon icon="i-lucide-bot" class="size-4" />
        </span>
        <span class="me-auto flex min-w-0 flex-col">
          <span class="truncate text-sm font-medium text-n-slate-12">
            {{ agent.name }}
          </span>
          <span class="text-xs tabular-nums text-n-slate-11">
            {{
              t('ANALYTICS.AI.AGENT_ROW', {
                conversations: agent.metrics.conversations_handled.current,
                rate: Math.round(agent.metrics.auto_resolution_rate.current),
              })
            }}
          </span>
        </span>
        <Icon
          icon="i-lucide-arrow-right"
          class="size-4 shrink-0 text-n-slate-9 group-hover:text-n-blue-11"
        />
      </RouterLink>
    </li>
  </ul>
</template>

<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';
import CardError from '../../home/components/CardError.vue';
import ConversationsChart from './ConversationsChart.vue';
import { durationText } from '../analyticsView';
import { overviewProps } from './overviewProps';

// Variant C · Compare: the AI agent and the team side by side, the same numbers in each, the better side marked.
const props = defineProps(overviewProps);
const emit = defineEmits(['retry']);
const { t } = useI18n();

const raw = key => props.metrics[key].raw.value ?? 0;

const sides = computed(() => {
  const aiConversations = raw('ai_conversations');
  const aiRate = raw('resolved');
  const teamConversations = props.team.reduce(
    (sum, person) => sum + person.conversations,
    0
  );
  const teamSolved = props.team.reduce((sum, person) => sum + person.solved, 0);
  return {
    ai: {
      conversations: aiConversations,
      solved: Math.round((aiRate * aiConversations) / 100),
      rate: aiRate,
      firstReply: null,
      handed: raw('handed'),
    },
    team: {
      conversations: teamConversations,
      solved: teamSolved,
      rate: teamConversations
        ? Math.round((teamSolved / teamConversations) * 100)
        : 0,
      firstReply: props.metrics.first_reply.raw.value,
      handed: null,
    },
  };
});

const better = (ai, team, lowerIsBetter = false) => {
  if (ai === null || team === null || ai === team) return null;
  return (lowerIsBetter ? ai < team : ai > team) ? 'ai' : 'team';
};

const rows = computed(() => {
  const { ai, team } = sides.value;
  return [
    {
      key: 'conversations',
      label: t('ANALYTICS.COMPARE.CONVERSATIONS'),
      ai: ai.conversations,
      team: team.conversations,
    },
    {
      key: 'solved',
      label: t('ANALYTICS.COMPARE.SOLVED'),
      ai: ai.solved,
      team: team.solved,
    },
    {
      key: 'rate',
      label: t('ANALYTICS.COMPARE.RATE'),
      ai: `${ai.rate}%`,
      team: `${team.rate}%`,
      better: better(ai.rate, team.rate),
    },
    {
      key: 'first_reply',
      label: t('ANALYTICS.COMPARE.FIRST_REPLY'),
      ai: t('ANALYTICS.COMPARE.INSTANT'),
      team: durationText(team.firstReply, t),
    },
    {
      key: 'handed',
      label: t('ANALYTICS.COMPARE.HANDED'),
      ai: ai.handed,
      team: '–',
    },
  ];
});

const columns = computed(() => [
  {
    key: 'ai',
    title: t('ANALYTICS.COMPARE.AI'),
    icon: 'i-lucide-bot',
    chip: 'bg-n-blue-3 text-n-blue-11',
  },
  {
    key: 'team',
    title: t('ANALYTICS.COMPARE.TEAM'),
    icon: 'i-lucide-users',
    chip: 'bg-n-amber-3 text-n-amber-11',
  },
]);
</script>

<template>
  <div
    v-if="hasError"
    class="rounded-card bg-n-solid-2 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
  >
    <CardError @retry="emit('retry')" />
  </div>
  <div v-else class="grid grid-cols-1 gap-4 md:grid-cols-2">
    <SectionCard v-for="column in columns" :key="column.key">
      <div class="flex items-center gap-2.5">
        <span
          class="grid size-8 place-items-center rounded-lg"
          :class="column.chip"
        >
          <Icon :icon="column.icon" class="size-4" />
        </span>
        <h2
          class="mb-0 font-display text-base font-semibold tracking-display text-n-slate-12"
        >
          {{ column.title }}
        </h2>
      </div>
      <div v-if="isLoading" class="flex flex-col gap-3" aria-busy="true">
        <span
          v-for="n in 5"
          :key="n"
          class="h-8 w-full animate-pulse rounded bg-n-alpha-2"
        />
      </div>
      <dl v-else class="m-0 flex flex-col divide-y divide-n-weak">
        <div
          v-for="row in rows"
          :key="row.key"
          class="flex items-center justify-between gap-3 py-2.5 first:pt-0 last:pb-0"
        >
          <dt class="text-sm text-n-slate-11">{{ row.label }}</dt>
          <dd
            class="m-0 flex items-center gap-2 font-display text-lg font-semibold tabular-nums text-n-slate-12"
          >
            <span
              v-if="row.better === column.key"
              class="rounded-full bg-n-teal-3 px-2 py-0.5 font-sans text-xs font-medium text-n-teal-11"
            >
              {{ t('ANALYTICS.COMPARE.BETTER') }}
            </span>
            {{ row[column.key] }}
          </dd>
        </div>
      </dl>
    </SectionCard>
  </div>
  <SectionCard :title="t('ANALYTICS.CHART.TITLE')">
    <ConversationsChart
      :days="days"
      :is-loading="isLoading"
      :has-error="hasError"
      @retry="emit('retry')"
    />
    <p class="mb-0 text-xs text-n-slate-11">
      {{
        t('ANALYTICS.COMPARE.RATING_BOTH', {
          rating: metrics.rating.value,
        })
      }}
    </p>
  </SectionCard>
</template>

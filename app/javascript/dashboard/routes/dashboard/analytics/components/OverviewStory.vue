<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';
import Sparkline from 'dashboard/components-next/kit/Sparkline.vue';
import CardError from '../../home/components/CardError.vue';
import ConversationsChart from './ConversationsChart.vue';
import TeamList from './TeamList.vue';
import { busiestDay, durationText } from '../analyticsView';
import { overviewProps } from './overviewProps';

// Variant B · Story: short sentences with the numbers, each with a small chart beside it.
const props = defineProps(overviewProps);
const emit = defineEmits(['retry']);
const { t, locale } = useI18n();

const LINE_TONES = {
  blue: 'text-n-blue-9',
  teal: 'text-n-teal-9',
  amber: 'text-n-amber-9',
  violet: 'text-n-violet-9',
};
const CHANGE_TONES = {
  good: 'text-n-teal-11',
  bad: 'text-n-ruby-11',
  neutral: 'text-n-slate-11',
};

const raw = key => props.metrics[key].raw.value;

const stories = computed(() => {
  const { metrics } = props;
  const rating = raw('rating');
  return [
    {
      key: 'resolved',
      text: t('ANALYTICS.STORY.RESOLVED', {
        rate: raw('resolved') ?? 0,
        count: raw('ai_conversations') ?? 0,
      }),
      metric: metrics.resolved,
    },
    {
      key: 'handed',
      text: t('ANALYTICS.STORY.HANDED', {
        count: raw('handed') ?? 0,
        time: durationText(raw('first_reply'), t),
      }),
      metric: metrics.handed,
    },
    {
      key: 'team_solved',
      text: t('ANALYTICS.STORY.TEAM_SOLVED', {
        count: raw('team_solved') ?? 0,
      }),
      metric: metrics.team_solved,
    },
    {
      key: 'rating',
      text:
        rating === null
          ? t('ANALYTICS.STORY.NO_RATING')
          : t('ANALYTICS.STORY.RATING', { rating }),
      metric: metrics.rating,
    },
  ];
});

const busiest = computed(() => {
  const day = busiestDay(props.rawDays);
  if (!day) return '';
  const date = new Date(`${day.date}T12:00:00`).toLocaleDateString(
    locale.value,
    { weekday: 'long', day: 'numeric', month: 'long' }
  );
  return t('ANALYTICS.STORY.BUSIEST', { date, count: day.ai + day.team });
});
</script>

<template>
  <div
    v-if="hasError"
    class="rounded-card bg-n-solid-2 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
  >
    <CardError @retry="emit('retry')" />
  </div>
  <SectionCard v-else :title="t('ANALYTICS.STORY.TITLE', { days: period })">
    <div v-if="isLoading" class="flex flex-col gap-4" aria-busy="true">
      <span
        v-for="n in 4"
        :key="n"
        class="h-12 w-full animate-pulse rounded bg-n-alpha-2"
      />
    </div>
    <ul v-else class="m-0 flex list-none flex-col divide-y divide-n-weak p-0">
      <li
        v-for="story in stories"
        :key="story.key"
        class="flex items-center gap-6 py-4 first:pt-0 last:pb-0"
      >
        <div class="me-auto flex min-w-0 flex-col gap-1">
          <p
            class="mb-0 font-display text-lg leading-snug tracking-display text-n-slate-12"
          >
            {{ story.text }}
          </p>
          <span
            v-if="story.metric.change"
            class="text-xs"
            :class="CHANGE_TONES[story.metric.changeTone]"
          >
            {{
              t('ANALYTICS.STORY.CHANGE', {
                change: story.metric.change,
                days: period,
              })
            }}
          </span>
        </div>
        <Sparkline
          v-if="story.metric.points.some(Boolean)"
          :points="story.metric.points"
          class="hidden h-10 w-32 shrink-0 sm:block"
          :class="LINE_TONES[story.metric.tone]"
          aria-hidden="true"
        />
      </li>
    </ul>
  </SectionCard>
  <div class="grid grid-cols-1 gap-4 lg:grid-cols-3">
    <SectionCard class="lg:col-span-2" :title="t('ANALYTICS.CHART.TITLE')">
      <p v-if="busiest && !isLoading" class="mb-0 text-sm text-n-slate-11">
        {{ busiest }}
      </p>
      <ConversationsChart
        :days="days"
        :is-loading="isLoading"
        :has-error="hasError"
        @retry="emit('retry')"
      />
    </SectionCard>
    <SectionCard
      :title="t('ANALYTICS.TEAM_LIST.TITLE')"
      :link-label="t('ANALYTICS.TEAM_LIST.SEE_ALL')"
      :to="{ name: 'analytics_team', query: { period } }"
    >
      <TeamList :team="team" :is-loading="isLoading" />
    </SectionCard>
  </div>
</template>

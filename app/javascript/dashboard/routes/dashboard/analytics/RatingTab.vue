<script setup>
import { computed, toRef } from 'vue';
import { useI18n } from 'vue-i18n';
import CSATReportsAPI from 'dashboard/api/csatReports';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';
import MetricTiles from './components/MetricTiles.vue';
import RatingBars from './components/RatingBars.vue';
import CommentList from './components/CommentList.vue';
import {
  analyticsMetrics,
  commentRows,
  metricView,
  ratingRows,
} from './analyticsView';
import { LOADERS, useAnalyticsData } from './useAnalyticsData';

// Customer rating: the average and how many rated, against the period before; how the ratings split; the latest
// comments.
const props = defineProps({ period: { type: Number, required: true } });

const { t } = useI18n();

const { data, isLoading, hasError, reload } = useAnalyticsData(
  toRef(props, 'period'),
  {
    activity: LOADERS.activity,
    csat: ({ since, until }) =>
      CSATReportsAPI.getMetrics({ from: since, to: until }),
    csatPrevious: ({ previous }) =>
      CSATReportsAPI.getMetrics({ from: previous.since, to: previous.until }),
    responses: ({ since, until }) =>
      CSATReportsAPI.get({ page: 1, from: since, to: until }),
  }
);

const metrics = computed(() => analyticsMetrics(data.value));
const tiles = computed(() => [
  metricView('rating', metrics.value.rating, t('ANALYTICS.METRICS.RATING'), t),
  metricView(
    'ratings_count',
    metrics.value.ratings_count,
    t('ANALYTICS.METRICS.RATINGS_COUNT'),
    t
  ),
  metricView(
    'happy_share',
    metrics.value.happy_share,
    t('ANALYTICS.METRICS.HAPPY_SHARE'),
    t
  ),
  metricView(
    'reply_share',
    metrics.value.reply_share,
    t('ANALYTICS.METRICS.REPLY_SHARE'),
    t
  ),
]);
const ratings = computed(() => ratingRows(data.value.csat));
const comments = computed(() => commentRows(data.value.responses));
</script>

<template>
  <MetricTiles
    :tiles="tiles"
    :is-loading="isLoading"
    :has-error="hasError"
    @retry="reload"
  />
  <div class="grid grid-cols-1 gap-4 lg:grid-cols-2">
    <SectionCard
      :title="t('ANALYTICS.RATING.SPLIT_TITLE')"
      :link-label="t('ANALYTICS.LINKS.RATING')"
      :to="{ name: 'csat_reports' }"
    >
      <RatingBars
        :rows="ratings"
        :is-loading="isLoading"
        :has-error="hasError"
        @retry="reload"
      />
    </SectionCard>
    <SectionCard
      :title="t('ANALYTICS.RATING.COMMENTS_TITLE')"
      :link-label="t('ANALYTICS.LINKS.ALL_COMMENTS')"
      :to="{ name: 'csat_reports' }"
    >
      <CommentList
        :comments="comments"
        :is-loading="isLoading"
        :has-error="hasError"
        @retry="reload"
      />
    </SectionCard>
  </div>
</template>

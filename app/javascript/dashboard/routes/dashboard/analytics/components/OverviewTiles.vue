<script setup>
import { computed } from 'vue';
import MetricTile from 'dashboard/components-next/kit/MetricTile.vue';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';
import TopicsCard from '../../home/components/TopicsCard.vue';
import CardError from '../../home/components/CardError.vue';
import ConversationsChart from './ConversationsChart.vue';
import TeamList from './TeamList.vue';
import { overviewProps } from './overviewProps';

// Variant A · Tiles and one chart.
const props = defineProps(overviewProps);
const emit = defineEmits(['retry']);

const TILES = ['conversations', 'resolved', 'first_reply', 'rating'];
const tiles = computed(() => TILES.map(key => props.metrics[key]));
</script>

<template>
  <div
    v-if="hasError"
    class="rounded-card bg-n-solid-2 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
  >
    <CardError @retry="emit('retry')" />
  </div>
  <div v-else class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
    <MetricTile
      v-for="tile in tiles"
      :key="tile.key"
      :label="tile.label"
      :value="tile.value"
      :icon="tile.icon"
      :tone="tile.tone"
      :change="tile.change"
      :change-tone="tile.changeTone"
      :points="tile.points"
      :is-loading="isLoading"
    />
  </div>
  <SectionCard
    :title="$t('ANALYTICS.CHART.TITLE')"
    :link-label="$t('ANALYTICS.CHART.LINK')"
    :to="{ name: 'conversation_reports' }"
  >
    <ConversationsChart
      :days="rawDays"
      :period="period"
      :is-loading="isLoading"
      :has-error="hasError"
      @retry="emit('retry')"
    />
  </SectionCard>
  <div class="grid grid-cols-1 gap-4 lg:grid-cols-2">
    <TopicsCard
      :topics="topics"
      :is-loading="isLoading"
      :has-error="hasError"
      @retry="emit('retry')"
    />
    <SectionCard
      :title="$t('ANALYTICS.TEAM_LIST.TITLE')"
      :link-label="$t('ANALYTICS.TEAM_LIST.SEE_ALL')"
      :to="{ name: 'analytics_team', query: { period } }"
    >
      <TeamList :team="team" :is-loading="isLoading" />
    </SectionCard>
  </div>
</template>

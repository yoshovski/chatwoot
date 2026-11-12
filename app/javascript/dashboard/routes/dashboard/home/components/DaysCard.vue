<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import DayBars from 'dashboard/components-next/kit/DayBars.vue';
import EmptyState from 'dashboard/components-next/kit/EmptyState.vue';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';
import CardError from './CardError.vue';

const props = defineProps({
  // [{ label, ai, team }]
  days: { type: Array, default: () => [] },
  isLoading: { type: Boolean, default: false },
  hasError: { type: Boolean, default: false },
});

const emit = defineEmits(['retry']);

const { t } = useI18n();
const isEmpty = computed(() => props.days.every(day => !day.ai && !day.team));
</script>

<template>
  <SectionCard :title="t('HOME.V2.DAYS.TITLE')">
    <span
      v-if="isLoading"
      class="h-40 w-full animate-pulse rounded bg-n-alpha-2"
      aria-busy="true"
    />
    <CardError v-else-if="hasError" @retry="emit('retry')" />
    <EmptyState
      v-else-if="isEmpty"
      icon="i-lucide-chart-column"
      :title="t('HOME.V2.DAYS.EMPTY')"
    />
    <DayBars
      v-else
      :days="days"
      :label="t('HOME.V2.DAYS.TITLE')"
      :ai-label="t('HOME.V2.DAYS.AI')"
      :team-label="t('HOME.V2.DAYS.TEAM')"
    />
  </SectionCard>
</template>

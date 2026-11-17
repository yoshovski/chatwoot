<script setup>
import { ref } from 'vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import HomeDateRangePicker from './HomeDateRangePicker.vue';
import DaysCard from './DaysCard.vue';
import MetricStrip from './MetricStrip.vue';
import CardError from './CardError.vue';

defineProps({
  period: { type: Number, required: true },
  dateRange: { type: Array, required: true },
  days: { type: Array, required: true },
  metrics: { type: Array, required: true },
  to: { type: Object, default: null },
  isLoading: { type: Boolean, default: false },
  hasError: { type: Boolean, default: false },
});
const emit = defineEmits(['selectDates', 'retry']);
const line = ref(false);
const modeClass = active =>
  active
    ? 'bg-n-solid-1 text-n-blue-11 shadow-sm'
    : 'text-n-slate-11 hover:bg-n-alpha-2';
</script>

<template>
  <section
    class="flex min-w-0 flex-col gap-2.5"
    aria-labelledby="home-performance"
  >
    <div class="flex flex-wrap items-center justify-between gap-2">
      <h2
        id="home-performance"
        class="m-0 font-display text-base font-semibold text-n-slate-12"
      >
        {{ $t('HOME.DASHBOARD.PERFORMANCE') }}
      </h2>
      <div class="flex flex-wrap items-center gap-2.5">
        <HomeDateRangePicker
          :range="dateRange"
          @apply="emit('selectDates', $event)"
        />
        <div
          class="flex items-center gap-1 rounded-lg bg-n-alpha-2 p-1"
          role="group"
          :aria-label="$t('HOME.DASHBOARD.CHART_TYPE')"
        >
          <button
            v-tooltip.top="$t('HOME.DASHBOARD.BAR_CHART')"
            type="button"
            class="grid size-7 place-items-center rounded-md focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
            :class="modeClass(!line)"
            :aria-pressed="!line"
            :aria-label="$t('HOME.DASHBOARD.BAR_CHART')"
            @click="line = false"
          >
            <Icon icon="i-lucide-chart-column" class="size-3.5" />
          </button>
          <button
            v-tooltip.top="$t('HOME.DASHBOARD.LINE_CHART')"
            type="button"
            class="grid size-7 place-items-center rounded-md focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
            :class="modeClass(line)"
            :aria-pressed="line"
            :aria-label="$t('HOME.DASHBOARD.LINE_CHART')"
            @click="line = true"
          >
            <Icon icon="i-lucide-chart-line" class="size-3.5" />
          </button>
        </div>
      </div>
    </div>
    <CardError v-if="hasError" @retry="emit('retry')" />
    <template v-else>
      <MetricStrip
        compact
        :metrics="metrics"
        :period="period"
        :is-loading="isLoading"
      />
      <DaysCard
        compact
        :line="line"
        :days="days"
        :period="period"
        :is-loading="isLoading"
        :to="to"
      />
    </template>
  </section>
</template>

<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  responseWindow: {
    type: String,
    default: 'always',
  },
  name: {
    type: String,
    default: '',
  },
});

const { t, locale } = useI18n();

// A Monday, used only to get localized weekday names.
const REFERENCE_MONDAY = new Date(Date.UTC(2024, 0, 1));
const DAY_COUNT = 7;
const WEEKDAY_COUNT = 5;
// Share of the day before 09:00, between 09:00 and 17:00, and after 17:00.
const SEGMENTS = ['basis-[37.5%]', 'basis-[33.3%]', 'basis-[29.2%]'];
const TIME_MARKS = ['00:00', '09:00', '17:00', '24:00'];

const coversSegment = (isWeekday, segment) => {
  if (props.responseWindow === 'always') return true;
  const isBusinessTime = isWeekday && segment === 1;
  return props.responseWindow === 'business_hours'
    ? isBusinessTime
    : !isBusinessTime;
};

const days = computed(() => {
  const format = new Intl.DateTimeFormat(locale.value, {
    weekday: 'short',
    timeZone: 'UTC',
  });
  return Array.from({ length: DAY_COUNT }, (_, index) => {
    const date = new Date(REFERENCE_MONDAY);
    date.setUTCDate(date.getUTCDate() + index);
    const isWeekday = index < WEEKDAY_COUNT;
    return {
      label: format.format(date),
      segments: SEGMENTS.map((basis, segment) => ({
        basis,
        covered: coversSegment(isWeekday, segment),
      })),
    };
  });
});
</script>

<template>
  <div
    class="flex flex-col gap-2.5 px-5 py-4 rounded-xl outline outline-1 outline-n-weak bg-n-solid-1"
  >
    <div class="flex flex-wrap items-center justify-between gap-2">
      <span class="text-sm font-semibold text-n-slate-12">
        {{ t('CAPTAIN.ASSISTANTS.SETTINGS.WORKING_HOURS.WEEK') }}
      </span>
      <div class="flex items-center gap-4 text-xs text-n-slate-11">
        <span class="flex items-center gap-1.5">
          <span class="rounded-sm size-2.5 bg-n-brand" />
          {{ name }}
        </span>
        <span class="flex items-center gap-1.5">
          <span class="rounded-sm size-2.5 bg-n-slate-5" />
          {{ t('CAPTAIN.ASSISTANTS.SETTINGS.WORKING_HOURS.LEGEND_TEAM') }}
        </span>
      </div>
    </div>
    <div
      v-for="day in days"
      :key="day.label"
      class="flex items-center gap-3"
      aria-hidden="true"
    >
      <span class="w-10 text-xs text-n-slate-11 shrink-0">{{ day.label }}</span>
      <div class="flex flex-1 h-3 gap-0.5 overflow-hidden rounded">
        <span
          v-for="(segment, index) in day.segments"
          :key="index"
          class="h-full"
          :class="[
            segment.basis,
            segment.covered ? 'bg-n-brand' : 'bg-n-slate-5',
          ]"
        />
      </div>
    </div>
    <div
      class="flex gap-0.5 text-xs ps-[3.25rem] text-n-slate-10"
      aria-hidden="true"
    >
      <span :class="SEGMENTS[0]">{{ TIME_MARKS[0] }}</span>
      <span :class="SEGMENTS[1]">{{ TIME_MARKS[1] }}</span>
      <span class="flex justify-between" :class="SEGMENTS[2]">
        <span>{{ TIME_MARKS[2] }}</span>
        <span>{{ TIME_MARKS[3] }}</span>
      </span>
    </div>
    <p class="mb-0 text-xs text-n-slate-11">
      {{ t('CAPTAIN.ASSISTANTS.SETTINGS.WORKING_HOURS.NOTE', { name }) }}
    </p>
  </div>
</template>

<script setup>
import { computed, ref, useId } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMediaQuery } from '@vueuse/core';
import {
  addMonths,
  differenceInCalendarDays,
  format,
  isSameMonth,
  isValid,
  parseISO,
  startOfMonth,
  startOfWeek,
  subDays,
} from 'date-fns';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { getWeeksForMonth } from 'dashboard/components/ui/DatePicker/helpers/DatePickerHelper';

const props = defineProps({
  range: { type: Array, required: true },
});
const emit = defineEmits(['apply']);
const { locale, t } = useI18n();
const dialog = ref(null);
const titleId = useId();
const draftStart = ref('');
const draftEnd = ref('');
const visibleMonth = ref(new Date());
const selectingEnd = ref(false);
const today = ref(new Date());
const wide = useMediaQuery('(min-width: 768px)');
const dayKey = date => format(date, 'yyyy-MM-dd');
const todayKey = computed(() => dayKey(today.value));

const formatRange = (start, end) => {
  const dateFormat = new Intl.DateTimeFormat(locale.value, {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
  return dateFormat.formatRange(start, end);
};
const rangeLabel = computed(() => formatRange(...props.range));
const monthLabel = month =>
  new Intl.DateTimeFormat(locale.value, {
    month: 'long',
    year: 'numeric',
  }).format(month);

const presets = computed(() => {
  const date = today.value;
  const lastWeek = startOfWeek(subDays(date, 7), { weekStartsOn: 1 });
  const rolling = length => [subDays(date, length - 1), date];
  return [
    { label: t('HOME.DASHBOARD.TODAY'), dates: rolling(1) },
    {
      label: t('HOME.DASHBOARD.YESTERDAY'),
      dates: rolling(1).map(day => subDays(day, 1)),
    },
    {
      label: t('HOME.DASHBOARD.LAST_WEEK'),
      dates: [lastWeek, subDays(startOfWeek(date, { weekStartsOn: 1 }), 1)],
    },
    {
      label: t('DATE_PICKER.DATE_RANGE_OPTIONS.LAST_7_DAYS'),
      dates: rolling(7),
    },
    {
      label: t('DATE_PICKER.DATE_RANGE_OPTIONS.MONTH_TO_DATE'),
      dates: [startOfMonth(date), date],
    },
    {
      label: t('DATE_PICKER.DATE_RANGE_OPTIONS.LAST_30_DAYS'),
      dates: rolling(30),
    },
    { label: t('HOME.DASHBOARD.LAST_90_DAYS'), dates: rolling(90) },
  ];
});
const calendars = computed(() =>
  [visibleMonth.value, addMonths(visibleMonth.value, 1)].map(month => {
    const weeks = getWeeksForMonth(month);
    const weekdays = new Intl.DateTimeFormat(locale.value, {
      weekday: 'short',
    });
    const fullDate = new Intl.DateTimeFormat(locale.value, {
      dateStyle: 'full',
    });
    return {
      key: dayKey(month),
      title: monthLabel(month),
      weekdays: weeks[0].map(day => ({
        key: day.getDay(),
        label: weekdays.format(day),
      })),
      days: weeks.flat().map(date => {
        const key = dayKey(date);
        return {
          key,
          number: date.getDate(),
          label: fullDate.format(date),
          inMonth: isSameMonth(date, month),
          future: key > todayKey.value,
          selected: key === draftStart.value || key === draftEnd.value,
          inRange: key > draftStart.value && key < draftEnd.value,
        };
      }),
    };
  })
);
const valid = computed(() => {
  const from = parseISO(draftStart.value);
  const to = parseISO(draftEnd.value);
  if (!isValid(from) || !isValid(to) || draftEnd.value > todayKey.value)
    return false;
  const days = differenceInCalendarDays(to, from);
  return days >= 0 && days < 90;
});

const firstMonthFor = start =>
  startOfMonth(
    wide.value && isSameMonth(start, today.value) ? addMonths(start, -1) : start
  );
const setDraft = ([start, end]) => {
  draftStart.value = dayKey(start);
  draftEnd.value = dayKey(end);
  visibleMonth.value = firstMonthFor(start);
  selectingEnd.value = false;
};
const nextMonthDisabled = computed(
  () =>
    addMonths(visibleMonth.value, wide.value ? 1 : 0) >=
    startOfMonth(today.value)
);
const isPresetSelected = ({ dates }) =>
  dayKey(dates[0]) === draftStart.value && dayKey(dates[1]) === draftEnd.value;
const open = () => {
  today.value = new Date();
  setDraft(props.range);
  dialog.value.showModal();
};
const close = () => dialog.value.close();
const navigate = offset => {
  visibleMonth.value = addMonths(visibleMonth.value, offset);
};
const selectDay = ({ key }) => {
  if (selectingEnd.value) {
    [draftStart.value, draftEnd.value] = [draftStart.value, key].sort();
  } else {
    draftStart.value = key;
    draftEnd.value = key;
  }
  selectingEnd.value = !selectingEnd.value;
};
const revealStart = () => {
  selectingEnd.value = false;
  const start = parseISO(draftStart.value);
  if (isValid(start)) visibleMonth.value = firstMonthFor(start);
};
const apply = () => {
  if (!valid.value) return;
  emit('apply', [parseISO(draftStart.value), parseISO(draftEnd.value)]);
  close();
};
</script>

<template>
  <button
    type="button"
    class="inline-flex min-h-9 items-center gap-2 rounded-lg border border-n-weak bg-n-solid-2 px-2.5 text-sm font-medium text-n-slate-12 hover:bg-n-slate-3 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand sm:px-3"
    :aria-label="`${$t('HOME.V2.PERIOD.LABEL')}, ${rangeLabel}`"
    aria-haspopup="dialog"
    @click="open"
  >
    <Icon icon="i-lucide-calendar-days" class="size-4 text-n-slate-11" />
    <span>{{ rangeLabel }}</span>
    <Icon icon="i-lucide-chevron-down" class="size-4 text-n-slate-11" />
  </button>

  <dialog
    ref="dialog"
    :aria-labelledby="titleId"
    class="m-auto max-h-[calc(100dvh-2rem)] w-[calc(100%-1.5rem)] max-w-[52rem] overflow-y-auto rounded-2xl border border-n-container bg-n-solid-1 p-0 text-n-slate-12 shadow-xl backdrop:bg-black/20"
  >
    <h2 :id="titleId" class="sr-only">{{ $t('HOME.V2.PERIOD.LABEL') }}</h2>
    <div
      class="grid sm:grid-cols-[minmax(0,1fr)_10rem] md:grid-cols-[minmax(0,1fr)_12rem]"
    >
      <div class="flex min-w-0 flex-col gap-4 p-3 sm:p-4">
        <div class="grid grid-cols-2 gap-2 rounded-lg bg-n-slate-3 p-2">
          <label
            class="flex min-w-0 flex-col gap-1 text-xs font-medium text-n-slate-11"
          >
            {{ $t('DATE_PICKER.DATE_RANGE_INPUT.START') }}
            <input
              v-model="draftStart"
              type="date"
              class="!m-0 min-w-0 !text-sm"
              :max="todayKey"
              @change="revealStart"
            />
          </label>
          <label
            class="flex min-w-0 flex-col gap-1 text-xs font-medium text-n-slate-11"
          >
            {{ $t('DATE_PICKER.DATE_RANGE_INPUT.END') }}
            <input
              v-model="draftEnd"
              type="date"
              class="!m-0 min-w-0 !text-sm"
              :max="todayKey"
              @change="selectingEnd = false"
            />
          </label>
        </div>
        <div class="flex items-start gap-1 sm:gap-2">
          <button
            type="button"
            class="mt-0.5 grid size-8 shrink-0 place-items-center rounded-md text-n-slate-11 hover:bg-n-slate-3"
            :aria-label="$t('HOME.DASHBOARD.PREVIOUS_MONTH')"
            @click="navigate(-1)"
          >
            <Icon icon="i-lucide-chevron-left" class="size-5 rtl:rotate-180" />
          </button>
          <div class="grid min-w-0 flex-1 grid-cols-1 gap-4 md:grid-cols-2">
            <section
              v-for="(calendar, index) in calendars"
              :key="calendar.key"
              :aria-label="calendar.title"
              :class="{ 'hidden md:block': index === 1 }"
            >
              <h3
                class="mb-2 mt-1.5 text-center text-sm font-semibold text-n-slate-12"
              >
                {{ calendar.title }}
              </h3>
              <div class="grid grid-cols-7 text-center">
                <span
                  v-for="day in calendar.weekdays"
                  :key="day.key"
                  class="py-1 text-xs text-n-slate-11"
                >
                  {{ day.label }}
                </span>
                <template v-for="day in calendar.days" :key="day.key">
                  <button
                    v-if="day.inMonth"
                    type="button"
                    class="min-h-8 min-w-0 text-sm tabular-nums hover:enabled:bg-n-blue-5 focus-visible:z-10 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand disabled:text-n-slate-9"
                    :class="{
                      'rounded-md bg-n-brand text-white hover:enabled:bg-n-blue-10':
                        day.selected,
                      'bg-n-blue-3 text-n-blue-11': day.inRange,
                    }"
                    :disabled="day.future"
                    :aria-label="day.label"
                    :aria-pressed="day.selected"
                    @click="selectDay(day)"
                  >
                    {{ day.number }}
                  </button>
                  <span v-else aria-hidden="true" />
                </template>
              </div>
            </section>
          </div>
          <button
            type="button"
            class="mt-0.5 grid size-8 shrink-0 place-items-center rounded-md text-n-slate-11 hover:bg-n-slate-3"
            :aria-label="$t('HOME.DASHBOARD.NEXT_MONTH')"
            :disabled="nextMonthDisabled"
            @click="navigate(1)"
          >
            <Icon icon="i-lucide-chevron-right" class="size-5 rtl:rotate-180" />
          </button>
        </div>
        <p v-if="!valid" class="m-0 text-xs text-n-ruby-11" role="status">
          {{ $t('HOME.DASHBOARD.INVALID_RANGE') }}
        </p>
      </div>
      <aside
        class="flex flex-col gap-3 border-t border-n-weak p-3 sm:border-s sm:border-t-0 sm:p-4"
      >
        <div class="flex flex-wrap gap-1 sm:flex-col">
          <button
            v-for="preset in presets"
            :key="preset.label"
            type="button"
            class="min-h-8 rounded-lg px-2 text-start text-sm text-n-slate-12 hover:bg-n-slate-3"
            :class="{
              'bg-n-blue-3 font-medium text-n-blue-11':
                isPresetSelected(preset),
            }"
            :aria-pressed="isPresetSelected(preset)"
            @click="setDraft(preset.dates)"
          >
            {{ preset.label }}
          </button>
        </div>
        <div class="mt-auto flex gap-2 sm:flex-col">
          <button
            type="button"
            class="min-h-9 flex-1 rounded-lg bg-n-brand px-3 text-sm font-medium text-white hover:enabled:brightness-110 disabled:opacity-50"
            :disabled="!valid"
            @click="apply"
          >
            {{ $t('DATE_PICKER.APPLY_BUTTON') }}
          </button>
          <button
            type="button"
            class="min-h-9 flex-1 rounded-lg border border-n-weak px-3 text-sm font-medium text-n-slate-12 hover:bg-n-slate-3"
            @click="close"
          >
            {{ $t('HOME.DASHBOARD.CANCEL') }}
          </button>
        </div>
      </aside>
    </div>
  </dialog>
</template>

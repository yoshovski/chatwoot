<script>
import parse from 'date-fns/parse';
import differenceInMinutes from 'date-fns/differenceInMinutes';
import { generateTimeSlots } from '../helpers/businessHour';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextSelect from 'dashboard/components-next/select/Select.vue';

const timeSlots = generateTimeSlots(30);

const groupByPeriod = slots =>
  ['AM', 'PM']
    .map(period => ({
      label: period,
      options: slots
        .filter(s => s.endsWith(period))
        .map(s => ({ value: s, label: s })),
    }))
    .filter(g => g.options.length);

export default {
  components: {
    Icon,
    NextSelect,
  },
  props: {
    dayName: {
      type: String,
      required: true,
    },
    timeSlot: {
      type: Object,
      default: () => ({
        from: '',
        to: '',
      }),
    },
  },
  emits: ['update'],
  computed: {
    fromTimeSlots() {
      return groupByPeriod(timeSlots);
    },
    toTimeSlots() {
      return groupByPeriod(timeSlots.filter(slot => slot !== '12:00 AM'));
    },
    isDayEnabled: {
      get() {
        return Boolean(this.timeSlot.from && this.timeSlot.to);
      },
      set(value) {
        const newSlot = value
          ? {
              ...this.timeSlot,
              from: timeSlots[0],
              to: timeSlots[16],
              valid: true,
              openAllDay: false,
            }
          : {
              ...this.timeSlot,
              from: '',
              to: '',
              valid: false,
              openAllDay: false,
            };
        this.$emit('update', newSlot);
      },
    },
    fromTime: {
      get() {
        return this.timeSlot.from;
      },
      set(value) {
        const fromDate = parse(value, 'hh:mm a', new Date());
        const valid = differenceInMinutes(this.toDate, fromDate) / 60 > 0;
        this.$emit('update', {
          ...this.timeSlot,
          from: value,
          valid,
        });
      },
    },
    toTime: {
      get() {
        return this.timeSlot.to;
      },
      set(value) {
        const toDate = parse(value, 'hh:mm a', new Date());
        if (value === '12:00 AM') {
          this.$emit('update', {
            ...this.timeSlot,
            to: value,
            valid: true,
          });
        } else {
          const valid = differenceInMinutes(toDate, this.fromDate) / 60 > 0;
          this.$emit('update', {
            ...this.timeSlot,
            to: value,
            valid,
          });
        }
      },
    },
    fromDate() {
      return parse(this.fromTime, 'hh:mm a', new Date());
    },
    toDate() {
      return parse(this.toTime, 'hh:mm a', new Date());
    },
    totalHours() {
      if (this.timeSlot.openAllDay) return '24h';

      const totalMinutes = differenceInMinutes(this.toDate, this.fromDate);
      const [h, m] = [Math.floor(totalMinutes / 60), totalMinutes % 60];

      return [h && `${h}h`, m && `${m}m`].filter(Boolean).join(' ') || '0m';
    },
    hasError() {
      return !this.timeSlot.valid;
    },
    isOpenAllDay: {
      get() {
        return this.timeSlot.openAllDay;
      },
      set(value) {
        if (value) {
          this.$emit('update', {
            ...this.timeSlot,
            from: '12:00 AM',
            to: '11:59 PM',
            valid: true,
            openAllDay: value,
          });
        } else {
          this.$emit('update', {
            ...this.timeSlot,
            from: '09:00 AM',
            to: '05:00 PM',
            valid: true,
            openAllDay: value,
          });
        }
      },
    },
  },
};
</script>

<template>
  <li
    class="grid min-w-0 items-center gap-2 p-3 sm:grid-cols-[7rem_minmax(0,1fr)] sm:gap-4 sm:px-4"
  >
    <label
      class="m-0 flex min-w-28 items-center gap-2 text-sm font-medium text-n-slate-12"
    >
      <input
        v-model="isDayEnabled"
        name="enable-day"
        class="m-0"
        type="checkbox"
      />
      {{ dayName }}
    </label>
    <div v-if="isDayEnabled" class="flex min-w-0 flex-1 flex-col gap-2">
      <div class="flex min-w-0 flex-wrap items-center gap-x-3 gap-y-2">
        <template v-if="!isOpenAllDay">
          <div
            class="grid min-w-0 grid-cols-[minmax(0,1fr)_1rem_minmax(0,1fr)] items-center gap-2"
          >
            <NextSelect
              v-model="fromTime"
              stretch
              :aria-label="
                $t('INBOX_MGMT.WEBSITE_SETTINGS.FROM_TIME', { day: dayName })
              "
              :groups="fromTimeSlots"
              :placeholder="$t('INBOX_MGMT.BUSINESS_HOURS.DAY.CHOOSE')"
            />
            <Icon icon="i-lucide-minus" class="size-4 text-n-slate-10" />
            <NextSelect
              v-model="toTime"
              stretch
              :aria-label="
                $t('INBOX_MGMT.WEBSITE_SETTINGS.TO_TIME', { day: dayName })
              "
              :groups="toTimeSlots"
              :placeholder="$t('INBOX_MGMT.BUSINESS_HOURS.DAY.CHOOSE')"
            />
          </div>
        </template>
        <label class="m-0 flex items-center gap-2 text-sm text-n-slate-11">
          <input
            v-model="isOpenAllDay"
            name="enable-open-all-day"
            type="checkbox"
            class="m-0"
          />
          {{ $t('INBOX_MGMT.BUSINESS_HOURS.ALL_DAY') }}
        </label>
        <span
          v-if="!hasError && !isOpenAllDay"
          class="ms-auto whitespace-nowrap text-xs text-n-slate-11"
        >
          {{ totalHours }}
        </span>
      </div>
      <span v-if="hasError" class="text-xs text-n-ruby-11">
        {{ $t('INBOX_MGMT.BUSINESS_HOURS.DAY.VALIDATION_ERROR') }}
      </span>
    </div>
    <span v-else class="text-sm text-n-slate-11">
      {{ $t('INBOX_MGMT.BUSINESS_HOURS.DAY.UNAVAILABLE') }}
    </span>
  </li>
</template>

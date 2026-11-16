<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  inboxes: { type: Array, default: () => [] },
  status: { type: String, default: 'loading' },
});

const emit = defineEmits(['retry']);
const { t, locale } = useI18n();
const U = 'CAPTAIN.AGENT_UX.CONFIGURATION.SCHEDULE';
const weekday = computed(
  () =>
    new Intl.DateTimeFormat(locale.value, { weekday: 'long', timeZone: 'UTC' })
);
// 7 January 2024 was a Sunday, matching the inbox API's zero-based weekday.
const dayName = day => weekday.value.format(Date.UTC(2024, 0, 7 + day));
const time = (hour, minute) =>
  [hour, minute].map(value => String(value).padStart(2, '0')).join(':');
const dayHours = day => {
  if (day.closed_all_day) return t(`${U}.CLOSED`);
  if (day.open_all_day) return t(`${U}.ALL_DAY`);
  return t(`${U}.RANGE`, {
    start: time(day.open_hour, day.open_minutes),
    end: time(day.close_hour, day.close_minutes),
  });
};
</script>

<template>
  <section class="flex min-w-0 flex-col gap-3">
    <div>
      <h2 class="m-0 text-base font-semibold text-n-slate-12">
        {{ t(`${U}.CHANNEL_HOURS`) }}
      </h2>
      <p class="m-0 mt-1 text-sm text-n-slate-11">
        {{ t(`${U}.EXPLANATION`) }}
      </p>
    </div>
    <p
      v-if="status === 'loading'"
      role="status"
      class="m-0 text-sm text-n-slate-11"
    >
      {{ t(`${U}.LOADING`) }}
    </p>
    <div
      v-else-if="status === 'error'"
      class="flex flex-wrap items-center gap-2"
    >
      <p role="alert" class="m-0 text-sm text-n-ruby-11">
        {{ t(`${U}.ERROR`) }}
      </p>
      <Button
        type="button"
        :label="t(`${U}.RETRY`)"
        size="sm"
        variant="faded"
        @click="emit('retry')"
      />
    </div>
    <p v-else-if="!inboxes.length" class="m-0 text-sm text-n-slate-11">
      {{ t(`${U}.EMPTY`) }}
    </p>
    <ul v-else class="m-0 flex list-none flex-col gap-2 p-0">
      <li
        v-for="inbox in inboxes"
        :key="inbox.id"
        class="min-w-0 rounded-xl border border-n-weak bg-n-solid-1 p-3 text-sm"
      >
        <details v-if="inbox.working_hours_enabled">
          <summary
            class="cursor-pointer break-words font-medium text-n-slate-12"
          >
            {{ inbox.name }} · {{ inbox.timezone }}
          </summary>
          <dl class="m-0 mt-2 flex flex-col gap-1 text-n-slate-11">
            <div
              v-for="day in inbox.working_hours"
              :key="day.day_of_week"
              class="flex flex-wrap justify-between gap-x-4"
            >
              <dt>{{ dayName(day.day_of_week) }}</dt>
              <dd class="m-0 tabular-nums">{{ dayHours(day) }}</dd>
            </div>
          </dl>
        </details>
        <div v-else class="flex flex-wrap gap-x-2 break-words">
          <span class="min-w-0 font-medium text-n-slate-12">{{
            inbox.name
          }}</span>
          <span class="text-n-slate-11">{{ t(`${U}.UNRESTRICTED`) }}</span>
        </div>
      </li>
    </ul>
  </section>
</template>

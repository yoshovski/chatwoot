<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  billing: { type: Object, required: true },
});

const DAY = 24 * 60 * 60 * 1000;
const { t } = useI18n();

const daysLeft = computed(() =>
  Math.ceil((new Date(props.billing.trial_ends_at) - Date.now()) / DAY)
);
const ended = computed(() => daysLeft.value <= 0);
const ai = computed(() => props.billing.products?.ai_conversations || {});
const capped = computed(() => ai.value.period === 'trial' && ai.value.limit !== null);
const capReached = computed(() => capped.value && ai.value.used >= ai.value.limit);
const paused = computed(() => ended.value || capReached.value);

const title = computed(() => {
  if (ended.value) return t('ACCOUNT_SUBSCRIPTION.TRIAL_BANNER.ENDED');
  return t('ACCOUNT_SUBSCRIPTION.TRIAL_BANNER.TITLE', {
    days: t('ACCOUNT_SUBSCRIPTION.TRIAL_BANNER.DAYS', daysLeft.value),
  });
});
const message = computed(() => {
  if (ended.value) return t('ACCOUNT_SUBSCRIPTION.TRIAL_BANNER.ENDED_HELP');
  if (capReached.value)
    return t('ACCOUNT_SUBSCRIPTION.TRIAL_BANNER.CAP_REACHED', {
      limit: ai.value.limit,
    });
  if (capped.value)
    return t('ACCOUNT_SUBSCRIPTION.TRIAL_BANNER.AI_LEFT', {
      left: Math.max(0, ai.value.limit - ai.value.used),
      limit: ai.value.limit,
    });
  return t('ACCOUNT_SUBSCRIPTION.TRIAL_BANNER.AI_UNCAPPED');
});
</script>

<template>
  <div
    class="flex items-start gap-3 rounded-xl border px-4 py-3"
    :class="
      paused
        ? 'border-n-amber-6 bg-n-amber-2 text-n-amber-11'
        : 'border-n-blue-6 bg-n-blue-2 text-n-blue-11'
    "
    role="status"
  >
    <span
      :class="paused ? 'i-lucide-circle-pause' : 'i-lucide-hourglass'"
      class="mt-0.5 size-4 shrink-0"
      aria-hidden="true"
    />
    <div class="flex min-w-0 flex-col gap-0.5">
      <p class="m-0 text-sm font-medium">{{ title }}</p>
      <p class="m-0 text-sm text-n-slate-11">{{ message }}</p>
    </div>
  </div>
</template>

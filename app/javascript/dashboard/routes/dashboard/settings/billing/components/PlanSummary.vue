<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  billing: { type: Object, required: true },
});

const { t, locale } = useI18n();
const plan = computed(() => props.billing.plan);
const money = (cents, currency) =>
  new Intl.NumberFormat(locale.value, { style: 'currency', currency }).format(
    cents / 100
  );
const price = computed(() => {
  if (!plan.value?.monthly_price_cents) return '';
  return t('ACCOUNT_SUBSCRIPTION.PLAN.PER_MONTH', {
    price: money(plan.value.monthly_price_cents, plan.value.currency),
  });
});
const status = computed(() => {
  if (props.billing.trial_enabled)
    return t('ACCOUNT_SUBSCRIPTION.PLAN.STATUS_TRIAL');
  if (props.billing.payment_status === 'active')
    return t('ACCOUNT_SUBSCRIPTION.PLAN.STATUS_ACTIVE');
  return t('ACCOUNT_SUBSCRIPTION.PLAN.STATUS_MANAGED');
});
// Plan feature keys are the fixed list Super Admin plans govern.
// eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys
const featureLabel = key => t(`ACCOUNT_SUBSCRIPTION.PLAN_FEATURES.${key}`);
</script>

<template>
  <section
    class="flex flex-col gap-4 rounded-xl border border-n-weak bg-n-solid-1 p-4 sm:p-5"
  >
    <div
      v-if="plan"
      class="flex flex-wrap items-start justify-between gap-x-6 gap-y-3"
    >
      <div class="flex min-w-0 flex-col gap-1">
        <div class="flex flex-wrap items-center gap-2">
          <h2 class="m-0 text-lg font-semibold text-n-slate-12">
            {{ plan.name }}
          </h2>
          <span
            class="rounded-md bg-n-alpha-2 px-2 py-0.5 text-xs font-medium text-n-slate-11"
          >
            {{ status }}
          </span>
          <span
            v-if="billing.founder_plan"
            class="inline-flex items-center gap-1 rounded-md bg-n-amber-3 px-2 py-0.5 text-xs font-medium text-n-amber-11"
          >
            <span class="i-lucide-award size-3" aria-hidden="true" />
            {{ t('ACCOUNT_SUBSCRIPTION.PLAN.FOUNDER_BADGE') }}
          </span>
        </div>
        <p v-if="plan.description" class="m-0 text-sm text-n-slate-11">
          {{ plan.description }}
        </p>
      </div>
      <span
        v-if="price"
        class="shrink-0 text-base font-semibold tabular-nums text-n-slate-12"
      >
        {{ price }}
      </span>
    </div>
    <div v-else class="flex items-start gap-3">
      <span
        class="i-lucide-package mt-0.5 size-5 shrink-0 text-n-slate-10"
        aria-hidden="true"
      />
      <div class="flex flex-col gap-1">
        <h2 class="m-0 text-base font-semibold text-n-slate-12">
          {{ t('ACCOUNT_SUBSCRIPTION.PLAN.NONE') }}
        </h2>
        <p class="m-0 text-sm text-n-slate-11">
          {{ t('ACCOUNT_SUBSCRIPTION.PLAN.NONE_HELP') }}
        </p>
      </div>
    </div>
    <ul
      v-if="plan?.features.length"
      class="m-0 flex list-none flex-wrap gap-1.5 p-0"
      :aria-label="t('ACCOUNT_SUBSCRIPTION.PLAN.INCLUDES')"
    >
      <li
        v-for="feature in plan.features"
        :key="feature"
        class="inline-flex items-center gap-1 rounded-md bg-n-alpha-1 px-2 py-1 text-xs text-n-slate-12"
      >
        <span class="i-lucide-check size-3 text-n-teal-11" aria-hidden="true" />
        {{ featureLabel(feature) }}
      </li>
    </ul>
  </section>
</template>

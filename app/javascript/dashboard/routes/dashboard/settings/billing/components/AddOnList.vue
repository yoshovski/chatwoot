<script setup>
import { useI18n } from 'vue-i18n';

const props = defineProps({
  addOns: { type: Array, required: true },
  currency: { type: String, required: true },
});

const { t, locale } = useI18n();
const price = cents =>
  t('ACCOUNT_SUBSCRIPTION.ADD_ONS.PRICE', {
    price: new Intl.NumberFormat(locale.value, {
      style: 'currency',
      currency: props.currency,
    }).format(cents / 100),
  });
// Add-on keys are the fixed list Super Admin plans govern.
// eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys
const label = key => t(`ACCOUNT_SUBSCRIPTION.PLAN_FEATURES.${key}`);
</script>

<template>
  <section class="flex flex-col gap-2">
    <h2 class="m-0 text-sm font-medium text-n-slate-12">
      {{ t('ACCOUNT_SUBSCRIPTION.ADD_ONS.TITLE') }}
    </h2>
    <ul
      class="m-0 list-none divide-y divide-n-weak rounded-xl border border-n-weak bg-n-solid-1 p-0"
    >
      <li
        v-for="addOn in addOns"
        :key="addOn.key"
        class="flex flex-wrap items-center justify-between gap-x-4 gap-y-1 px-4 py-3"
      >
        <span class="text-sm text-n-slate-12">{{ label(addOn.key) }}</span>
        <span class="flex items-center gap-3 text-sm">
          <span class="tabular-nums text-n-slate-11">
            {{ price(addOn.price_cents) }}
          </span>
          <span
            class="rounded-md px-2 py-0.5 text-xs font-medium"
            :class="
              addOn.active
                ? 'bg-n-teal-3 text-n-teal-11'
                : 'bg-n-alpha-2 text-n-slate-11'
            "
          >
            {{
              addOn.active
                ? t('ACCOUNT_SUBSCRIPTION.ADD_ONS.ACTIVE')
                : t('ACCOUNT_SUBSCRIPTION.ADD_ONS.AVAILABLE')
            }}
          </span>
        </span>
      </li>
    </ul>
  </section>
</template>

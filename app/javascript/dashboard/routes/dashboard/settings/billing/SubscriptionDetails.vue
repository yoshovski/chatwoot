<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  billing: { type: Object, required: true },
  busy: { type: Boolean, default: false },
  paymentFailed: { type: Boolean, default: false },
  interval: { type: String, default: 'month' },
});
const emit = defineEmits(['pay', 'update:interval', 'refresh']);
const { t, locale } = useI18n();
// Status and invoice keys are restricted to payment-provider lifecycle values.
// eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys
const text = key => t(`ACCOUNT_SUBSCRIPTION.${key}`);
const details = computed(() => props.billing.stripe_details || {});
const invoice = computed(() => details.value.latest_invoice);
const terminal = computed(() =>
  ['canceled', 'incomplete_expired'].includes(props.billing.payment_status)
);
const status = computed(() => {
  if (props.billing.has_subscription) {
    return props.billing.payment_status === 'trialing' &&
      details.value.paid_extension
      ? 'renewal_deferred'
      : props.billing.payment_status;
  }
  if (props.billing.trial_enabled) {
    return new Date(props.billing.trial_ends_at) <= new Date()
      ? 'trial_ended'
      : 'trialing';
  }
  return 'manual';
});
const attention = computed(() =>
  ['past_due', 'unpaid', 'incomplete', 'paused'].includes(status.value)
);
const knownStatus = computed(() =>
  [
    'active',
    'renewal_deferred',
    'trialing',
    'trial_ended',
    'past_due',
    'unpaid',
    'incomplete',
    'incomplete_expired',
    'canceled',
    'paused',
    'manual',
  ].includes(status.value)
    ? status.value
    : 'unknown'
);
const canceling = computed(
  () =>
    props.billing.has_subscription &&
    !terminal.value &&
    (details.value.cancel_at_period_end || details.value.cancel_at)
);
const money = (cents, currency = props.billing.currency) =>
  new Intl.NumberFormat(locale.value, { style: 'currency', currency }).format(
    cents / 100
  );
const date = value =>
  new Date(value).toLocaleDateString(locale.value, {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
const currentPrice = computed(() => {
  if (
    details.value.amount_cents === null ||
    details.value.amount_cents === undefined
  )
    return null;
  return money(
    details.value.amount_cents * (details.value.quantity ?? 1),
    details.value.currency
  );
});
const yearlySavings = computed(() =>
  Math.max(
    0,
    props.billing.monthly_price_cents * 12 - props.billing.annual_price_cents
  )
);
const selectedPrice = computed(() =>
  props.interval === 'year'
    ? props.billing.annual_price_cents
    : props.billing.monthly_price_cents
);
const renewalDate = computed(() => {
  if (terminal.value) {
    return details.value.ended_at
      ? new Date(details.value.ended_at * 1000).toISOString()
      : null;
  }
  return details.value.cancel_at
    ? new Date(details.value.cancel_at * 1000).toISOString()
    : props.billing.period_ends_at;
});
const dateLabel = computed(() => {
  if (terminal.value) return 'ENDED_ON';
  if (canceling.value) return 'ENDS_ON';
  if (status.value === 'trialing') return 'FIRST_PAYMENT_ON';
  if (status.value === 'renewal_deferred') return 'NEXT_PAYMENT_ON';
  return status.value === 'active' ? 'NEXT_RENEWAL' : 'BILLING_PERIOD_END';
});
const changeDialog = ref(null);
const changeInterval = ref('year');
const changeQuantity = computed(() => details.value.quantity ?? 1);
const changePrice = option => {
  if (option === props.billing.billing_interval)
    return details.value.amount_cents;
  return option === 'year'
    ? props.billing.annual_price_cents
    : props.billing.monthly_price_cents;
};
const changeSavings = computed(() =>
  Math.max(
    0,
    (changePrice('month') * 12 - changePrice('year')) * changeQuantity.value
  )
);
const openChange = () => {
  changeInterval.value =
    props.billing.billing_interval === 'year' ? 'month' : 'year';
  changeDialog.value.open();
};
const reviewChange = () =>
  emit(
    'pay',
    canceling.value ? 'portal' : 'changeInterval',
    changeInterval.value
  );
</script>

<template>
  <section
    class="flex h-full min-w-0 flex-col rounded-2xl border border-n-weak bg-n-background p-5 sm:p-6"
  >
    <div class="flex flex-wrap items-center justify-between gap-3">
      <h2 class="m-0 text-base font-semibold text-n-slate-12">
        {{ text('SUBSCRIPTION') }}
      </h2>
      <span
        class="inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium"
        :class="
          attention
            ? 'bg-n-amber-2 text-n-amber-11'
            : status === 'active'
              ? 'bg-n-teal-2 text-n-teal-11'
              : 'bg-n-alpha-2 text-n-slate-11'
        "
      >
        <span
          :class="attention ? 'i-lucide-circle-alert' : 'i-lucide-circle-check'"
          class="size-3.5"
          aria-hidden="true"
        />
        {{ text(`STATUS.${knownStatus}`) }}
      </span>
    </div>
    <div
      v-if="billing.billing_sync_failed"
      class="mt-4 flex flex-wrap items-center justify-between gap-2 rounded-lg bg-n-amber-2 p-3"
      role="alert"
    >
      <span class="text-xs text-n-amber-11">{{ text('SYNC_ERROR') }}</span>
      <Button
        :label="text('RETRY')"
        variant="outline"
        color="slate"
        size="sm"
        @click="emit('refresh')"
      />
    </div>
    <div
      v-if="billing.has_subscription && !terminal"
      class="mt-6 flex flex-wrap items-baseline gap-2 tabular-nums"
    >
      <span class="text-4xl font-semibold tracking-tight text-n-slate-12">{{
        currentPrice ?? text('PRICE_UNAVAILABLE')
      }}</span>
      <span v-if="currentPrice !== null" class="text-sm text-n-slate-11">{{
        text(details.interval === 'year' ? 'YEARLY_CADENCE' : 'MONTHLY_CADENCE')
      }}</span>
    </div>
    <p
      v-if="
        attention ||
        knownStatus === 'manual' ||
        terminal ||
        knownStatus === 'trial_ended'
      "
      class="mb-0 mt-4 text-sm text-n-slate-11"
    >
      {{ text(`STATUS_HELP.${knownStatus}`) }}
    </p>
    <div
      v-if="canceling"
      class="mt-4 flex items-center gap-2 rounded-lg bg-n-amber-2 px-3 py-2 text-xs font-medium text-n-amber-11"
    >
      <span class="i-lucide-calendar-x size-4 shrink-0" aria-hidden="true" />{{
        text('RENEWAL_OFF')
      }}
    </div>
    <dl class="mb-0 mt-5 space-y-4 text-sm">
      <div
        v-if="billing.trial_enabled && !billing.has_subscription"
        class="flex flex-wrap items-center justify-between gap-2"
      >
        <dt class="inline-flex items-center gap-2 text-n-slate-11">
          <span class="i-lucide-calendar size-4" aria-hidden="true" />{{
            text(status === 'trial_ended' ? 'TRIAL_ENDED_ON' : 'TRIAL_END_DATE')
          }}
        </dt>
        <dd class="m-0 font-medium text-n-slate-12">
          {{ date(billing.trial_ends_at) }}
        </dd>
      </div>
      <div
        v-if="billing.has_subscription && renewalDate"
        class="flex flex-wrap items-center justify-between gap-2"
      >
        <dt class="inline-flex items-center gap-2 text-n-slate-11">
          <span class="i-lucide-calendar size-4" aria-hidden="true" />{{
            text(dateLabel)
          }}
        </dt>
        <dd class="m-0 font-medium text-n-slate-12">{{ date(renewalDate) }}</dd>
      </div>
      <div
        v-if="invoice"
        class="flex flex-wrap items-center justify-between gap-2"
      >
        <dt class="inline-flex items-center gap-2 text-n-slate-11">
          <span class="i-lucide-receipt size-4" aria-hidden="true" />{{
            text('LATEST_INVOICE')
          }}
        </dt>
        <dd
          class="m-0 flex items-center gap-2 font-medium tabular-nums text-n-slate-12"
        >
          {{ money(invoice.total, invoice.currency) }}
          <span
            class="rounded-md px-2 py-1 text-xs"
            :class="
              invoice.status === 'paid'
                ? 'bg-n-teal-2 text-n-teal-11'
                : 'bg-n-alpha-2 text-n-slate-11'
            "
            >{{ text(`INVOICE_STATUS.${invoice.status}`) }}</span
          >
        </dd>
      </div>
    </dl>
    <details
      v-if="billing.has_subscription"
      class="mt-4 text-xs text-n-slate-11"
    >
      <summary
        class="w-fit cursor-pointer rounded py-1 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-blue-9"
      >
        {{ text('BILLING_DETAILS') }}
      </summary>
      <p
        v-if="billing.period_started_at && billing.period_ends_at"
        class="mb-0 mt-2 text-xs"
      >
        {{
          t('ACCOUNT_SUBSCRIPTION.DATE_RANGE', {
            start: date(billing.period_started_at),
            end: date(billing.period_ends_at),
          })
        }}
      </p>
      <p class="mb-0 mt-2 text-xs">{{ text('INVOICE_TOTAL_HELP') }}</p>
    </details>
    <div
      v-if="billing.can_checkout && (!billing.has_subscription || terminal)"
      class="mt-5"
    >
      <fieldset class="m-0 mb-4 border-0 p-0">
        <legend class="sr-only">{{ text('BILLING_INTERVAL') }}</legend>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <label
            v-for="option in ['month', 'year']"
            :key="option"
            class="flex cursor-pointer flex-col gap-1 rounded-xl border p-3 focus-within:ring-2 focus-within:ring-n-blue-9"
            :class="
              interval === option
                ? 'border-n-blue-7 bg-n-blue-2'
                : 'border-n-weak'
            "
          >
            <input
              class="sr-only"
              type="radio"
              name="billing-interval"
              :value="option"
              :checked="interval === option"
              :disabled="busy"
              @change="emit('update:interval', option)"
            />
            <span class="text-sm font-medium text-n-slate-12">{{
              text(option === 'year' ? 'YEARLY' : 'MONTHLY')
            }}</span>
            <span class="text-xl font-semibold text-n-slate-12">{{
              money(
                option === 'year'
                  ? billing.annual_price_cents
                  : billing.monthly_price_cents
              )
            }}</span>
            <span
              v-if="option === 'year' && yearlySavings > 0"
              class="text-xs text-n-teal-11"
              >{{
                t('ACCOUNT_SUBSCRIPTION.YEARLY_SAVING', {
                  amount: money(yearlySavings),
                })
              }}</span
            >
          </label>
        </div>
      </fieldset>
      <p v-if="billing.setup_fee_cents" class="mb-3 text-xs text-n-slate-11">
        {{
          t('ACCOUNT_SUBSCRIPTION.SETUP_FEE', {
            amount: money(billing.setup_fee_cents),
          })
        }}
      </p>
      <Button
        :label="
          t('ACCOUNT_SUBSCRIPTION.SUBSCRIBE_PRICE', {
            amount: money(selectedPrice),
            frequency: text(interval === 'year' ? 'ANNUALLY' : 'MONTHLY'),
          })
        "
        :is-loading="busy"
        :disabled="busy"
        class="w-full"
        @click="emit('pay', 'checkout')"
      />
    </div>
    <div v-if="billing.can_manage" class="mt-auto pt-5">
      <p v-if="paymentFailed" class="mb-3 text-xs text-n-ruby-11" role="alert">
        {{ text('PAYMENT_ERROR') }}
      </p>
      <div class="flex flex-wrap gap-2 border-t border-n-weak pt-4">
        <Button
          v-if="billing.can_change_interval && !billing.billing_sync_failed"
          :label="text('CHANGE_BILLING')"
          icon="i-lucide-arrow-left-right"
          variant="outline"
          color="blue"
          size="sm"
          :disabled="busy"
          @click="openChange"
        />
        <Button
          :label="text(attention ? 'RESOLVE_PAYMENT' : 'PAYMENTS_INVOICES')"
          :variant="attention ? 'solid' : 'outline'"
          :color="attention ? 'blue' : 'slate'"
          size="sm"
          :is-loading="busy"
          :disabled="busy"
          @click="emit('pay', 'portal')"
        />
      </div>
    </div>
    <Dialog
      ref="changeDialog"
      type="edit"
      width="md"
      :title="text('CHANGE_BILLING')"
      :confirm-button-label="
        text(canceling ? 'RESUME_IN_STRIPE' : 'REVIEW_CHANGE')
      "
      :disable-confirm-button="
        !canceling && changeInterval === billing.billing_interval
      "
      :is-loading="busy"
      @confirm="reviewChange"
    >
      <p v-if="paymentFailed" class="m-0 text-sm text-n-ruby-11" role="alert">
        {{ text('PAYMENT_ERROR') }}
      </p>
      <fieldset class="m-0 border-0 p-0">
        <legend class="sr-only">{{ text('BILLING_INTERVAL') }}</legend>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <label
            v-for="option in ['month', 'year']"
            :key="option"
            class="flex cursor-pointer flex-col gap-2 rounded-xl border p-4 focus-within:ring-2 focus-within:ring-n-blue-9"
            :class="
              changeInterval === option
                ? 'border-n-blue-7 bg-n-blue-2'
                : 'border-n-weak'
            "
          >
            <input
              v-model="changeInterval"
              class="sr-only"
              type="radio"
              name="change-billing-interval"
              :value="option"
              :disabled="busy"
            />
            <span
              class="flex items-center justify-between text-sm font-medium text-n-slate-12"
              >{{ text(option === 'year' ? 'YEARLY' : 'MONTHLY')
              }}<span
                v-if="option === billing.billing_interval"
                class="text-xs text-n-slate-11"
                >{{ text('CURRENT') }}</span
              ></span
            >
            <span class="text-xl font-semibold text-n-slate-12">{{
              money(changePrice(option) * changeQuantity)
            }}</span>
            <span class="text-xs text-n-slate-11">{{
              text(option === 'year' ? 'PER_YEAR' : 'PER_MONTH')
            }}</span>
            <span
              v-if="option === 'year' && changeSavings > 0"
              class="text-xs font-medium text-n-teal-11"
              >{{
                t('ACCOUNT_SUBSCRIPTION.YEARLY_SAVING', {
                  amount: money(changeSavings),
                })
              }}</span
            >
          </label>
        </div>
      </fieldset>
      <p
        v-if="canceling"
        class="m-0 rounded-lg bg-n-amber-2 p-3 text-sm text-n-amber-11"
      >
        {{ text('RESUME_BEFORE_CHANGE') }}
      </p>
      <p v-else class="m-0 text-sm text-n-slate-11">
        {{ text('CHANGE_REVIEW_HELP') }}
      </p>
    </Dialog>
  </section>
</template>

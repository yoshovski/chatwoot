<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  billing: { type: Object, required: true },
  busy: { type: Boolean, default: false },
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
    details.value.amount_cents * (details.value.quantity || 1),
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
</script>

<template>
  <section class="rounded-2xl border border-n-weak bg-n-background p-6">
    <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
      <h2 class="m-0 text-base font-semibold text-n-slate-12">
        {{ text('SUBSCRIPTION') }}
      </h2>
      <span
        class="rounded-md px-2.5 py-1 text-xs font-medium"
        :class="
          attention
            ? 'bg-n-amber-2 text-n-amber-11'
            : status === 'active'
              ? 'bg-n-teal-2 text-n-teal-11'
              : 'bg-n-alpha-2 text-n-slate-12'
        "
      >
        {{ text(`STATUS.${knownStatus}`) }}
      </span>
    </div>
    <div
      v-if="billing.billing_sync_failed"
      class="mb-5 rounded-xl bg-n-amber-2 p-4"
      role="alert"
    >
      <p class="m-0 mb-3 text-sm text-n-amber-11">{{ text('SYNC_ERROR') }}</p>
      <Button
        :label="text('RETRY')"
        variant="outline"
        color="slate"
        size="sm"
        @click="emit('refresh')"
      />
    </div>
    <p class="m-0 text-sm leading-6 text-n-slate-11">
      {{ text(`STATUS_HELP.${knownStatus}`) }}
    </p>
    <p v-if="canceling" class="mb-0 mt-3 text-sm leading-6 text-n-amber-11">
      <span class="block font-medium">{{
        text('CANCELLATION_SCHEDULED')
      }}</span>
      {{ text('CANCELING_HELP') }}
    </p>
    <div v-if="billing.has_subscription && !terminal" class="mt-5">
      <p class="m-0 mb-1 text-xs font-medium text-n-slate-11">
        {{ text('RECURRING_PRICE') }}
      </p>
      <p class="m-0 text-3xl font-semibold tracking-tight text-n-slate-12">
        {{ currentPrice ?? text('PRICE_UNAVAILABLE') }}
      </p>
      <p v-if="currentPrice !== null" class="mb-0 mt-1 text-sm text-n-slate-11">
        {{
          t('ACCOUNT_SUBSCRIPTION.RECURS_EVERY', {
            count: details.interval_count || 1,
            unit:
              details.interval === 'year'
                ? t(
                    'ACCOUNT_SUBSCRIPTION.YEAR_UNIT',
                    details.interval_count || 1
                  )
                : t(
                    'ACCOUNT_SUBSCRIPTION.MONTH_UNIT',
                    details.interval_count || 1
                  ),
          })
        }}
      </p>
      <p class="mb-0 mt-2 text-xs leading-5 text-n-slate-11">
        {{ text('INVOICE_TOTAL_HELP') }}
      </p>
    </div>
    <dl class="mb-0 mt-5 space-y-3 text-sm">
      <div
        v-if="billing.trial_enabled && !billing.has_subscription"
        class="flex flex-wrap justify-between gap-2"
      >
        <dt class="text-n-slate-11">
          {{
            text(status === 'trial_ended' ? 'TRIAL_ENDED_ON' : 'TRIAL_END_DATE')
          }}
        </dt>
        <dd class="m-0 font-medium text-n-slate-12">
          {{ date(billing.trial_ends_at) }}
        </dd>
      </div>
      <div
        v-if="billing.has_subscription && renewalDate"
        class="flex flex-wrap justify-between gap-2"
      >
        <dt class="text-n-slate-11">{{ text(dateLabel) }}</dt>
        <dd class="m-0 font-medium text-n-slate-12">{{ date(renewalDate) }}</dd>
      </div>
      <div
        v-if="
          billing.has_subscription &&
          billing.period_started_at &&
          billing.period_ends_at
        "
        class="flex flex-wrap justify-between gap-2"
      >
        <dt class="text-n-slate-11">
          {{
            text(terminal ? 'LAST_BILLING_PERIOD' : 'CURRENT_BILLING_PERIOD')
          }}
        </dt>
        <dd class="m-0 text-n-slate-12">
          {{
            t('ACCOUNT_SUBSCRIPTION.DATE_RANGE', {
              start: date(billing.period_started_at),
              end: date(billing.period_ends_at),
            })
          }}
        </dd>
      </div>
      <div
        v-if="invoice"
        class="flex flex-wrap justify-between gap-2 border-t border-n-weak pt-4"
      >
        <dt class="text-n-slate-11">{{ text('LATEST_INVOICE') }}</dt>
        <dd
          class="m-0 flex flex-wrap items-center gap-2 font-medium text-n-slate-12"
        >
          {{ money(invoice.total, invoice.currency) }}
          <span class="rounded-md bg-n-alpha-2 px-2 py-1 text-xs">{{
            text(`INVOICE_STATUS.${invoice.status}`)
          }}</span>
        </dd>
      </div>
    </dl>
    <div
      v-if="billing.can_checkout && (!billing.has_subscription || terminal)"
      class="mt-6 border-t border-n-weak pt-5"
    >
      <fieldset class="m-0 mb-5 border-0 p-0">
        <legend class="mb-3 text-sm font-medium text-n-slate-12">
          {{ text('BILLING_INTERVAL') }}
        </legend>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <label
            v-for="option in ['month', 'year']"
            :key="option"
            class="relative flex cursor-pointer flex-col gap-2 rounded-xl border p-4 focus-within:ring-2 focus-within:ring-n-blue-9"
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
            <span
              class="flex items-center justify-between text-sm font-medium text-n-slate-12"
            >
              {{ text(option === 'year' ? 'YEARLY' : 'MONTHLY') }}
              <span
                v-if="interval === option"
                class="i-lucide-circle-check size-4 text-n-blue-11"
                aria-hidden="true"
              />
            </span>
            <span class="text-xl font-semibold text-n-slate-12">{{
              money(
                option === 'year'
                  ? billing.annual_price_cents
                  : billing.monthly_price_cents
              )
            }}</span>
            <span class="text-xs text-n-slate-11">{{
              text(option === 'year' ? 'PER_YEAR' : 'PER_MONTH')
            }}</span>
            <span
              v-if="option === 'year' && yearlySavings > 0"
              class="text-xs font-medium text-n-teal-11"
            >
              {{
                t('ACCOUNT_SUBSCRIPTION.YEARLY_SAVING', {
                  amount: money(yearlySavings),
                })
              }}
            </span>
          </label>
        </div>
      </fieldset>
      <p v-if="billing.setup_fee_cents" class="mb-4 text-sm text-n-slate-11">
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
      <p class="mb-0 mt-3 text-xs leading-5 text-n-slate-11">
        {{ text('CHECKOUT_HELP') }}
      </p>
    </div>
    <Button
      v-if="billing.can_manage"
      class="mt-5 w-full"
      :label="text(attention ? 'RESOLVE_PAYMENT' : 'MANAGE')"
      :variant="attention ? 'solid' : 'outline'"
      :color="attention ? 'blue' : 'slate'"
      :is-loading="busy"
      :disabled="busy"
      @click="emit('pay', 'portal')"
    />
    <p
      v-if="billing.can_manage"
      class="mb-0 mt-3 text-xs leading-5 text-n-slate-11"
    >
      {{ text('PORTAL_HELP') }}
    </p>
  </section>
</template>

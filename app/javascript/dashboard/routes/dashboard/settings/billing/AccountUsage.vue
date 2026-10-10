<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { useAccountSubscription } from 'dashboard/composables/useAccountSubscription';
import api from 'dashboard/api/accountSubscription';
import Button from 'dashboard/components-next/button/Button.vue';
import ProgressMetric from 'dashboard/components-next/captain/pageComponents/overview/v2/ProgressMetric.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';

const { t, locale } = useI18n();
const { checkPermissions } = usePolicy();
const { billing, loading, loadFailed, refresh } = useAccountSubscription();
const canManage = computed(() => checkPermissions(['administrator']));
const paymentFailed = ref(false);
const busy = ref(false);
const interval = ref('month');
const date = value =>
  new Date(value).toLocaleDateString(locale.value, {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
const number = value => new Intl.NumberFormat(locale.value).format(value);
const money = cents =>
  new Intl.NumberFormat(locale.value, {
    style: 'currency',
    currency: billing.value.currency,
  }).format(cents / 100);
const limited = computed(() => billing.value?.monthly_limit !== null);
const remaining = computed(() =>
  Math.max(0, billing.value.monthly_limit - billing.value.consumed)
);
const percentage = computed(() =>
  billing.value.monthly_limit > 0
    ? Math.round((billing.value.consumed / billing.value.monthly_limit) * 100)
    : 0
);
const trialExpired = computed(
  () =>
    billing.value?.trial_enabled &&
    new Date(billing.value.trial_ends_at) <= new Date()
);
const statusLabel = computed(() => {
  if (trialExpired.value) return t('ACCOUNT_SUBSCRIPTION.TRIAL_ENDED');
  if (billing.value?.trial_enabled) return t('ACCOUNT_SUBSCRIPTION.TRIAL');
  if (billing.value?.payment_status === 'active')
    return t('ACCOUNT_SUBSCRIPTION.ACTIVE');
  if (billing.value?.payment_status === 'canceled')
    return t('ACCOUNT_SUBSCRIPTION.SUBSCRIPTION_ENDED');
  return t('ACCOUNT_SUBSCRIPTION.ACCOUNT_PLAN');
});
const warningText = computed(() => {
  if (billing.value?.ai_replies_paused) return t('ACCOUNT_SUBSCRIPTION.PAUSED');
  if (!billing.value?.warning) return '';
  if (billing.value.trial_enabled)
    return t('ACCOUNT_SUBSCRIPTION.TRIAL_WARNING');
  if (billing.value.consumed >= billing.value.monthly_limit)
    return t('ACCOUNT_SUBSCRIPTION.PAID_LIMIT_REACHED');
  return t('ACCOUNT_SUBSCRIPTION.PAID_WARNING');
});
const selectedPrice = computed(() =>
  interval.value === 'year'
    ? billing.value.annual_price_cents
    : billing.value.monthly_price_cents
);
const annualSavings = computed(() =>
  Math.max(
    0,
    billing.value.monthly_price_cents * 12 - billing.value.annual_price_cents
  )
);
const pay = async (action = 'checkout') => {
  busy.value = true;
  paymentFailed.value = false;
  try {
    const { data } = await api[action](interval.value);
    window.location.assign(data.url);
  } catch {
    paymentFailed.value = true;
  } finally {
    busy.value = false;
  }
};
</script>

<template>
  <SettingsLayout
    :is-loading="loading"
    :loading-message="t('ACCOUNT_SUBSCRIPTION.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('ACCOUNT_SUBSCRIPTION.TITLE')"
        :description="t('ACCOUNT_SUBSCRIPTION.DESCRIPTION')"
      />
    </template>
    <template #body>
      <div
        v-if="loadFailed"
        class="mb-4 flex items-center justify-between gap-4 rounded-xl border border-n-weak bg-n-background p-4"
        role="alert"
      >
        <p class="m-0 text-sm text-n-slate-11">
          {{ t('ACCOUNT_SUBSCRIPTION.LOAD_ERROR') }}
        </p>
        <Button
          :label="t('ACCOUNT_SUBSCRIPTION.RETRY')"
          variant="outline"
          color="slate"
          size="sm"
          @click="refresh"
        />
      </div>
      <div v-if="billing?.enabled" class="flex flex-col gap-6">
        <div
          v-if="warningText"
          class="flex items-start gap-3 rounded-xl border border-n-amber-6 bg-n-amber-2 p-4 text-n-amber-11"
          role="status"
        >
          <span
            class="i-lucide-circle-alert mt-0.5 size-5 shrink-0"
            aria-hidden="true"
          />
          <p class="m-0 text-sm leading-6">{{ warningText }}</p>
        </div>
        <div class="grid grid-cols-1 items-start gap-6 lg:grid-cols-2">
          <section class="rounded-2xl border border-n-weak bg-n-background p-6">
            <div class="mb-6 flex items-center justify-between gap-3">
              <h2 class="m-0 text-base font-semibold text-n-slate-12">
                {{ t('ACCOUNT_SUBSCRIPTION.CONVERSATIONS') }}
              </h2>
              <span
                class="rounded-md bg-n-alpha-2 px-2 py-1 text-xs font-medium text-n-slate-11"
                >{{ t('ACCOUNT_SUBSCRIPTION.MONTHLY_ALLOWANCE') }}</span
              >
            </div>
            <div class="mb-5 flex flex-wrap items-baseline gap-2 tabular-nums">
              <span
                class="text-4xl font-semibold tracking-tight text-n-slate-12"
                >{{ number(billing.consumed) }}</span
              >
              <span class="text-sm text-n-slate-11">{{
                limited
                  ? t('ACCOUNT_SUBSCRIPTION.OF_LIMIT', {
                      limit: number(billing.monthly_limit),
                    })
                  : t('ACCOUNT_SUBSCRIPTION.USED')
              }}</span>
            </div>
            <ProgressMetric
              v-if="limited && billing.monthly_limit > 0"
              :label="t('ACCOUNT_SUBSCRIPTION.CONVERSATIONS')"
              :show-label="false"
              :used="billing.consumed"
              :total="billing.monthly_limit"
              :usage-label="
                t('ACCOUNT_SUBSCRIPTION.REMAINING', {
                  count: number(remaining),
                })
              "
              :value-label="`${percentage}%`"
              :color="
                billing.warning ? 'rgb(var(--amber-9))' : 'rgb(var(--blue-9))'
              "
            />
            <p
              v-else
              class="m-0 flex items-center gap-2 text-sm text-n-slate-11"
            >
              <span class="i-lucide-circle-check size-4" aria-hidden="true" />{{
                limited
                  ? t('ACCOUNT_SUBSCRIPTION.NO_ALLOWANCE')
                  : t('ACCOUNT_SUBSCRIPTION.UNLIMITED')
              }}
            </p>
            <dl class="mb-0 mt-6 space-y-3 border-t border-n-weak pt-5 text-sm">
              <div class="flex flex-wrap justify-between gap-2">
                <dt class="text-n-slate-11">
                  {{ t('ACCOUNT_SUBSCRIPTION.RESET_DATE') }}
                </dt>
                <dd class="m-0 font-medium text-n-slate-12">
                  {{ date(billing.quota_resets_at) }}
                </dd>
              </div>
              <div class="flex flex-wrap justify-between gap-2">
                <dt class="text-n-slate-11">
                  {{ t('ACCOUNT_SUBSCRIPTION.USAGE_PERIOD') }}
                </dt>
                <dd class="m-0 text-n-slate-12">
                  {{
                    t('ACCOUNT_SUBSCRIPTION.DATE_RANGE', {
                      start: date(billing.quota_started_at),
                      end: date(billing.quota_resets_at),
                    })
                  }}
                </dd>
              </div>
            </dl>
            <p class="mb-0 mt-5 text-xs leading-5 text-n-slate-11">
              {{ t('ACCOUNT_SUBSCRIPTION.COUNTING') }}
            </p>
          </section>
          <section class="rounded-2xl border border-n-weak bg-n-background p-6">
            <div class="mb-6 flex flex-wrap items-center justify-between gap-3">
              <h2 class="m-0 text-base font-semibold text-n-slate-12">
                {{ t('ACCOUNT_SUBSCRIPTION.SUBSCRIPTION') }}
              </h2>
              <span
                class="rounded-md bg-n-alpha-2 px-2 py-1 text-xs font-medium text-n-slate-11"
                >{{ statusLabel }}</span
              >
            </div>
            <template v-if="canManage && billing.can_checkout">
              <fieldset class="m-0 mb-5 border-0 p-0">
                <legend class="mb-3 text-sm text-n-slate-11">
                  {{ t('ACCOUNT_SUBSCRIPTION.BILLING_INTERVAL') }}
                </legend>
                <div class="grid grid-cols-2 gap-3">
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
                      v-model="interval"
                      class="sr-only"
                      type="radio"
                      name="billing-interval"
                      :value="option"
                      :disabled="busy"
                    />
                    <span class="text-sm font-medium text-n-slate-12">{{
                      option === 'year'
                        ? t('ACCOUNT_SUBSCRIPTION.YEARLY')
                        : t('ACCOUNT_SUBSCRIPTION.MONTHLY')
                    }}</span>
                    <span class="text-xl font-semibold text-n-slate-12">{{
                      money(
                        option === 'year'
                          ? billing.annual_price_cents
                          : billing.monthly_price_cents
                      )
                    }}</span>
                    <span class="text-xs text-n-slate-11">{{
                      option === 'year'
                        ? t('ACCOUNT_SUBSCRIPTION.PER_YEAR')
                        : t('ACCOUNT_SUBSCRIPTION.PER_MONTH')
                    }}</span>
                    <span
                      v-if="option === 'year' && annualSavings > 0"
                      class="text-xs font-medium text-n-teal-11"
                    >
                      {{
                        t('ACCOUNT_SUBSCRIPTION.YEARLY_SAVING', {
                          amount: money(annualSavings),
                        })
                      }}
                    </span>
                  </label>
                </div>
              </fieldset>
              <p
                v-if="billing.setup_fee_cents"
                class="mb-4 text-sm text-n-slate-11"
              >
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
                  })
                "
                :is-loading="busy"
                :disabled="busy"
                class="w-full"
                @click="pay()"
              />
            </template>
            <template v-else>
              <p
                v-if="billing.monthly_price_cents > 0"
                class="mb-1 text-3xl font-semibold tracking-tight text-n-slate-12"
              >
                {{
                  money(
                    billing.billing_interval === 'year'
                      ? billing.annual_price_cents
                      : billing.monthly_price_cents
                  )
                }}
              </p>
              <p
                v-if="billing.monthly_price_cents > 0"
                class="m-0 text-sm text-n-slate-11"
              >
                {{
                  billing.billing_interval === 'year'
                    ? t('ACCOUNT_SUBSCRIPTION.PER_YEAR')
                    : t('ACCOUNT_SUBSCRIPTION.PER_MONTH')
                }}
              </p>
              <p v-else class="m-0 text-sm text-n-slate-11">
                {{ t('ACCOUNT_SUBSCRIPTION.MANAGED_PLAN') }}
              </p>
            </template>
            <dl
              v-if="billing.trial_enabled || billing.period_ends_at"
              class="mb-0 mt-5 space-y-3 border-t border-n-weak pt-5 text-sm"
            >
              <div
                v-if="billing.trial_enabled"
                class="flex flex-wrap justify-between gap-2"
              >
                <dt class="text-n-slate-11">
                  {{
                    trialExpired
                      ? t('ACCOUNT_SUBSCRIPTION.TRIAL_ENDED_ON')
                      : t('ACCOUNT_SUBSCRIPTION.TRIAL_END_DATE')
                  }}
                </dt>
                <dd class="m-0 font-medium text-n-slate-12">
                  {{ date(billing.trial_ends_at) }}
                </dd>
              </div>
              <div
                v-if="billing.period_ends_at"
                class="flex flex-wrap justify-between gap-2"
              >
                <dt class="text-n-slate-11">
                  {{ t('ACCOUNT_SUBSCRIPTION.BILLING_PERIOD_END') }}
                </dt>
                <dd class="m-0 font-medium text-n-slate-12">
                  {{ date(billing.period_ends_at) }}
                </dd>
              </div>
            </dl>
            <Button
              v-if="canManage && billing.can_manage"
              class="mt-5"
              :label="t('ACCOUNT_SUBSCRIPTION.MANAGE')"
              variant="outline"
              color="slate"
              :is-loading="busy"
              :disabled="busy"
              @click="pay('portal')"
            />
          </section>
        </div>
        <section
          v-if="canManage && billing.can_pay_customization"
          class="flex flex-col justify-between gap-4 rounded-2xl border border-n-weak bg-n-background p-6 sm:flex-row sm:items-center"
        >
          <div>
            <h2 class="m-0 text-base font-semibold text-n-slate-12">
              {{ t('ACCOUNT_SUBSCRIPTION.PAYMENT_REQUEST') }}
            </h2>
            <p class="mb-0 mt-1 text-sm text-n-slate-11">
              {{
                billing.custom_payment_description ||
                t('ACCOUNT_SUBSCRIPTION.CUSTOMIZATION')
              }}
            </p>
            <p class="mb-0 mt-2 text-lg font-semibold text-n-slate-12">
              {{ money(billing.custom_payment_cents) }}
            </p>
          </div>
          <Button
            :label="t('ACCOUNT_SUBSCRIPTION.PAY_NOW')"
            :is-loading="busy"
            :disabled="busy"
            @click="pay('payment')"
          />
        </section>
        <p v-if="paymentFailed" class="m-0 text-sm text-n-ruby-11" role="alert">
          {{ t('ACCOUNT_SUBSCRIPTION.PAYMENT_ERROR') }}
        </p>
        <section
          v-if="billing.history.length"
          class="overflow-hidden rounded-2xl border border-n-weak bg-n-background"
        >
          <h2
            class="m-0 border-b border-n-weak px-6 py-5 text-base font-semibold text-n-slate-12"
          >
            {{ t('ACCOUNT_SUBSCRIPTION.HISTORY') }}
          </h2>
          <table class="w-full text-sm">
            <thead class="bg-n-alpha-1 text-n-slate-11">
              <tr>
                <th scope="col" class="px-6 py-3 text-start font-medium">
                  {{ t('ACCOUNT_SUBSCRIPTION.MONTH') }}
                </th>
                <th scope="col" class="px-6 py-3 text-end font-medium">
                  {{ t('ACCOUNT_SUBSCRIPTION.CONVERSATIONS') }}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-n-weak">
              <tr
                v-for="month in billing.history"
                :key="month.period_started_at"
              >
                <td class="px-6 py-4 text-n-slate-12">
                  {{ date(month.period_started_at) }}
                </td>
                <td class="px-6 py-4 text-end tabular-nums text-n-slate-12">
                  {{ number(month.consumed) }}
                </td>
              </tr>
            </tbody>
          </table>
        </section>
      </div>
      <div
        v-else-if="!loadFailed"
        class="rounded-2xl border border-n-weak bg-n-background px-6 py-12 text-center"
      >
        <span
          class="i-lucide-credit-card mx-auto mb-4 block size-8 text-n-slate-10"
          aria-hidden="true"
        />
        <h2 class="mb-2 text-base font-semibold text-n-slate-12">
          {{ t('ACCOUNT_SUBSCRIPTION.NOT_CONFIGURED') }}
        </h2>
        <p class="m-0 text-sm text-n-slate-11">
          {{ t('ACCOUNT_SUBSCRIPTION.NOT_CONFIGURED_HELP') }}
        </p>
      </div>
    </template>
  </SettingsLayout>
</template>

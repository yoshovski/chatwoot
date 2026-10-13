<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { useAccountSubscription } from 'dashboard/composables/useAccountSubscription';
import api from 'dashboard/api/accountSubscription';
import Button from 'dashboard/components-next/button/Button.vue';
import ProgressMetric from 'dashboard/components-next/captain/pageComponents/overview/v2/ProgressMetric.vue';
import SubscriptionDetails from './SubscriptionDetails.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';

const { t, locale } = useI18n();
const { checkPermissions } = usePolicy();
const { currentAccount } = useAccount();
const { billing, loading, loadFailed, refresh } = useAccountSubscription();
const canManage = computed(() => checkPermissions(['administrator']));
onMounted(() => refresh());
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
const warningText = computed(() => {
  if (billing.value?.ai_replies_paused) return t('ACCOUNT_SUBSCRIPTION.PAUSED');
  if (!billing.value?.warning) return '';
  if (billing.value.trial_enabled)
    return t('ACCOUNT_SUBSCRIPTION.TRIAL_WARNING');
  if (billing.value.consumed >= billing.value.monthly_limit)
    return t('ACCOUNT_SUBSCRIPTION.PAID_LIMIT_REACHED');
  return t('ACCOUNT_SUBSCRIPTION.PAID_WARNING');
});
const includedFeatures = computed(() => [
  { icon: 'i-lucide-inbox', label: 'SHARED_INBOX', enabled: true },
  {
    icon: 'i-lucide-sparkles',
    label: 'AI_AGENT',
    enabled: currentAccount.value?.features?.captain_integration,
  },
  {
    icon: 'i-lucide-book-open',
    label: 'KNOWLEDGE',
    enabled:
      currentAccount.value?.features?.captain_integration ||
      currentAccount.value?.features?.native_ai_knowledge,
  },
  {
    icon: 'i-lucide-workflow',
    label: 'SCENARIOS',
    enabled: currentAccount.value?.features?.captain_integration_v2,
  },
]);
const historyPeriods = computed(() => {
  const periods = billing.value.history.filter(
    period =>
      new Date(period.period_started_at).getTime() !==
      new Date(billing.value.quota_started_at).getTime()
  );
  return [
    {
      period_started_at: billing.value.quota_started_at,
      consumed: billing.value.consumed,
      current: true,
    },
    ...periods,
  ];
});
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
        <section
          v-if="canManage"
          class="overflow-hidden rounded-2xl border border-n-blue-6 bg-gradient-to-br from-n-blue-2 via-n-background to-n-iris-2 p-6"
        >
          <div class="flex flex-wrap items-center justify-between gap-4">
            <div class="flex items-center gap-4">
              <span
                class="grid size-14 place-items-center rounded-2xl bg-n-blue-3 text-n-blue-11"
              >
                <span
                  :class="
                    billing.founder_plan
                      ? 'i-lucide-gem'
                      : 'i-lucide-credit-card'
                  "
                  class="size-7"
                  aria-hidden="true"
                />
              </span>
              <div class="flex flex-col gap-2">
                <span class="text-sm text-n-slate-11">{{
                  t('ACCOUNT_SUBSCRIPTION.CURRENT_PLAN')
                }}</span>
                <h2 class="m-0 text-2xl font-semibold text-n-slate-12">
                  {{
                    t(
                      billing.founder_plan
                        ? 'ACCOUNT_SUBSCRIPTION.FOUNDER_PLAN'
                        : 'ACCOUNT_SUBSCRIPTION.ACCOUNT_PLAN'
                    )
                  }}
                </h2>
              </div>
            </div>
            <span
              v-if="billing.founder_plan"
              class="inline-flex items-center gap-2 rounded-full border border-n-amber-6 bg-n-amber-2 px-4 py-2 text-sm font-medium text-n-amber-11"
            >
              <span class="i-lucide-award size-4" aria-hidden="true" />{{
                t('ACCOUNT_SUBSCRIPTION.FOUNDER_BADGE')
              }}
            </span>
          </div>
          <p
            v-if="billing.founder_plan"
            class="mb-0 mt-4 text-sm text-n-slate-11"
          >
            {{ t('ACCOUNT_SUBSCRIPTION.FOUNDER_HELP') }}
          </p>
        </section>
        <div
          class="grid grid-cols-1 items-start gap-6"
          :class="canManage ? 'lg:grid-cols-2' : ''"
        >
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
          <SubscriptionDetails
            v-if="canManage"
            v-model:interval="interval"
            :billing="billing"
            :busy="busy"
            @pay="pay"
            @refresh="refresh()"
          />
        </div>
        <section class="rounded-2xl border border-n-weak bg-n-background p-6">
          <h2 class="m-0 mb-5 text-base font-semibold text-n-slate-12">
            {{ t('ACCOUNT_SUBSCRIPTION.FEATURE_ACCESS') }}
          </h2>
          <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <div
              v-for="feature in includedFeatures"
              :key="feature.label"
              class="flex items-center gap-3 rounded-xl bg-n-alpha-1 p-4"
            >
              <span
                :class="feature.icon"
                class="size-5 shrink-0 text-n-blue-11"
                aria-hidden="true"
              />
              <div class="flex flex-col gap-1">
                <span class="text-sm font-medium text-n-slate-12">{{
                  t(`ACCOUNT_SUBSCRIPTION.FEATURES.${feature.label}`)
                }}</span>
                <span
                  class="inline-flex items-center gap-1 text-xs"
                  :class="
                    feature.enabled ? 'text-n-teal-11' : 'text-n-slate-11'
                  "
                >
                  <span
                    :class="
                      feature.enabled
                        ? 'i-lucide-circle-check'
                        : 'i-lucide-minus'
                    "
                    class="size-3"
                    aria-hidden="true"
                  />
                  {{
                    t(
                      feature.enabled
                        ? 'ACCOUNT_SUBSCRIPTION.INCLUDED'
                        : 'ACCOUNT_SUBSCRIPTION.NOT_ENABLED'
                    )
                  }}
                </span>
              </div>
            </div>
          </div>
        </section>
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
          class="overflow-hidden rounded-2xl border border-n-weak bg-n-background"
        >
          <h2
            class="m-0 border-b border-n-weak px-6 py-5 text-base font-semibold text-n-slate-12"
          >
            {{ t('ACCOUNT_SUBSCRIPTION.HISTORY') }}
          </h2>
          <div class="px-6 pt-5 pb-6">
            <div
              class="mb-5 flex flex-wrap items-center justify-between gap-2 text-sm text-n-slate-11"
            >
              <span>{{ t('ACCOUNT_SUBSCRIPTION.HISTORY_DESCRIPTION') }}</span>
              <span
                class="inline-flex items-center gap-1.5 rounded-full bg-n-blue-2 px-2.5 py-1 text-xs text-n-blue-11"
              >
                <span class="i-lucide-clock size-3.5" aria-hidden="true" />
                {{ t('ACCOUNT_SUBSCRIPTION.CURRENT_PERIOD_PARTIAL') }}
              </span>
            </div>
            <div class="overflow-x-auto">
              <table class="w-full text-start text-sm">
                <caption class="sr-only">
                  {{
                    t('ACCOUNT_SUBSCRIPTION.HISTORY_DESCRIPTION')
                  }}
                </caption>
                <thead>
                  <tr class="border-b border-n-weak">
                    <th
                      scope="col"
                      class="pb-3 text-start font-medium text-n-slate-11"
                    >
                      {{ t('ACCOUNT_SUBSCRIPTION.MONTH') }}
                    </th>
                    <th
                      scope="col"
                      class="pb-3 text-end font-medium text-n-slate-11"
                    >
                      {{ t('ACCOUNT_SUBSCRIPTION.CONVERSATIONS') }}
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="period in historyPeriods"
                    :key="period.period_started_at"
                    class="border-b border-n-weak last:border-0"
                  >
                    <th
                      scope="row"
                      class="py-3 text-start font-normal text-n-slate-12"
                    >
                      {{ date(period.period_started_at) }}
                      <span
                        v-if="period.current"
                        class="ms-2 text-xs text-n-blue-11"
                        >{{ t('ACCOUNT_SUBSCRIPTION.IN_PROGRESS') }}</span
                      >
                    </th>
                    <td
                      class="py-3 text-end font-medium tabular-nums text-n-slate-12"
                    >
                      {{ number(period.consumed) }}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
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

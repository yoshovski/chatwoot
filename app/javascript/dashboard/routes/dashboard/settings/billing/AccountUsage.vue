<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { LineChart } from '@chatwoot/viz';
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
const paymentAction = ref('');
const busy = ref(false);
const interval = ref('month');
const date = (value, timeZone) =>
  new Date(value).toLocaleDateString(locale.value, {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    timeZone,
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
const dailyUsage = computed(() => billing.value?.daily_usage || []);
const historyChart = computed(() => ({
  categories: dailyUsage.value.map(day =>
    new Date(`${day.date}T12:00:00Z`).toLocaleDateString(locale.value, {
      day: 'numeric',
      month: 'short',
      timeZone: 'UTC',
    })
  ),
  series: [
    {
      id: 'conversations',
      label: t('ACCOUNT_SUBSCRIPTION.CONVERSATIONS'),
      color: 'rgb(var(--blue-9))',
      pointBorderColor: 'rgb(var(--card-color))',
      data: dailyUsage.value.map(day => day.consumed),
    },
  ],
}));
// Keep the date axis legible while tooltips retain every day's full date.
const timelineLabels = computed(() => {
  const categories = historyChart.value.categories;
  if (categories.length <= 5) return categories;
  return Array.from(
    { length: 5 },
    (_, index) => categories[Math.round(((categories.length - 1) * index) / 4)]
  );
});
const historyDomain = computed(() => [
  0,
  Math.max(
    4,
    Math.ceil(Math.max(0, ...dailyUsage.value.map(day => day.consumed)) / 4) * 4
  ),
]);
const historyTotal = computed(() =>
  dailyUsage.value.reduce((sum, day) => sum + day.consumed, 0)
);
const pay = async (action = 'checkout', chosenInterval = interval.value) => {
  paymentAction.value = action;
  busy.value = true;
  paymentFailed.value = false;
  try {
    const { data } = await api[action](chosenInterval);
    window.location.assign(data.url);
  } catch {
    paymentFailed.value = true;
    await refresh();
  } finally {
    busy.value = false;
  }
};
</script>

<template>
  <SettingsLayout
    content-sized
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
      <div v-if="billing?.enabled" class="flex flex-col gap-5">
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
          class="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-n-blue-6 bg-gradient-to-r from-n-blue-2 to-n-background px-5 py-4"
        >
          <div class="flex flex-wrap items-center justify-between gap-4">
            <div class="flex items-center gap-4">
              <span
                class="grid size-10 place-items-center rounded-xl bg-n-blue-3 text-n-blue-11"
              >
                <span
                  :class="
                    billing.founder_plan
                      ? 'i-lucide-gem'
                      : 'i-lucide-credit-card'
                  "
                  class="size-5"
                  aria-hidden="true"
                />
              </span>
              <div class="flex flex-col gap-2">
                <span class="text-sm text-n-slate-11">{{
                  t('ACCOUNT_SUBSCRIPTION.CURRENT_PLAN')
                }}</span>
                <h2 class="m-0 text-lg font-semibold text-n-slate-12">
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
        </section>
        <div
          class="grid grid-cols-1 items-stretch gap-5"
          :class="canManage ? 'lg:grid-cols-2' : ''"
        >
          <section
            class="flex min-w-0 flex-col rounded-2xl border border-n-weak bg-n-background p-5 sm:p-6"
          >
            <div class="mb-6 flex flex-wrap items-center justify-between gap-3">
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
            <p class="mb-0 mt-auto pt-5 text-xs leading-5 text-n-slate-11">
              {{ t('ACCOUNT_SUBSCRIPTION.COUNTING') }}
            </p>
          </section>
          <SubscriptionDetails
            v-if="canManage"
            v-model:interval="interval"
            :billing="billing"
            :busy="busy"
            :payment-failed="paymentFailed && paymentAction !== 'payment'"
            @pay="pay"
            @refresh="refresh()"
          />
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
        <p
          v-if="paymentFailed && paymentAction === 'payment'"
          class="m-0 text-sm text-n-ruby-11"
          role="alert"
        >
          {{ t('ACCOUNT_SUBSCRIPTION.PAYMENT_ERROR') }}
        </p>
        <section
          class="min-w-0 rounded-2xl border border-n-weak bg-n-background p-5 sm:p-6"
        >
          <div class="mb-5 flex flex-wrap items-start justify-between gap-3">
            <div>
              <h2 class="m-0 text-base font-semibold text-n-slate-12">
                {{ t('ACCOUNT_SUBSCRIPTION.USAGE_TIMELINE') }}
              </h2>
              <p class="mb-0 mt-1 text-xs text-n-slate-11">
                {{ t('ACCOUNT_SUBSCRIPTION.DAILY_USAGE_HELP') }}
              </p>
            </div>
            <span
              class="rounded-lg bg-n-blue-2 px-3 py-2 text-sm font-medium tabular-nums text-n-blue-11"
              >{{
                t('ACCOUNT_SUBSCRIPTION.TIMELINE_TOTAL', {
                  count: number(historyTotal),
                })
              }}</span
            >
          </div>
          <LineChart
            v-if="dailyUsage.length > 1"
            :data="historyChart"
            :format-value="number"
            :y-domain="historyDomain"
            :height="220"
            :point-radius="3"
            :show-values="dailyUsage.length <= 7"
            :x-inset="0"
            :aria-label="t('ACCOUNT_SUBSCRIPTION.USAGE_TIMELINE')"
            class="w-full [&_.cw-viz-line\_\_x-tick]:hidden [--cw-viz-line-label-color:rgb(var(--slate-11))] [--cw-viz-line-axis-color:rgb(var(--slate-4))] [--cw-viz-line-tooltip-background:rgb(var(--solid-2))] [--cw-viz-line-tooltip-color:rgb(var(--slate-12))] [--cw-viz-line-tooltip-border-color:rgb(var(--border-strong))]"
          />
          <div
            v-if="dailyUsage.length > 1"
            aria-hidden="true"
            class="relative -mt-7 mb-3 flex justify-between gap-2 ps-14 pe-6 text-[0.625rem] text-n-slate-11"
          >
            <span v-for="label in timelineLabels" :key="label">{{
              label
            }}</span>
          </div>
          <p
            v-else
            class="mb-0 flex h-32 items-center justify-center text-sm text-n-slate-11"
          >
            {{ t('ACCOUNT_SUBSCRIPTION.TIMELINE_STARTING') }}
          </p>
          <details class="mt-3 text-xs text-n-slate-11">
            <summary
              class="w-fit cursor-pointer rounded py-1 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-blue-9"
            >
              {{ t('ACCOUNT_SUBSCRIPTION.VIEW_DAILY_TOTALS') }}
            </summary>
            <dl
              class="mt-2 grid grid-cols-2 gap-2 sm:grid-cols-4 lg:grid-cols-6"
            >
              <div
                v-for="day in dailyUsage"
                :key="day.date"
                class="rounded-lg bg-n-alpha-1 p-2"
              >
                <dt>{{ date(`${day.date}T12:00:00Z`, 'UTC') }}</dt>
                <dd class="m-0 mt-1 font-medium tabular-nums text-n-slate-12">
                  {{ number(day.consumed) }}
                </dd>
              </div>
            </dl>
          </details>
        </section>
        <details class="rounded-xl border border-n-weak bg-n-background p-5">
          <summary class="cursor-pointer text-sm font-medium text-n-slate-12">
            {{ t('ACCOUNT_SUBSCRIPTION.FEATURE_ACCESS') }}
          </summary>
          <div
            class="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4"
          >
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
        </details>
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

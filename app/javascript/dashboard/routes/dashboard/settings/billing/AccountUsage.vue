<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { useAccountSubscription } from 'dashboard/composables/useAccountSubscription';
import api from 'dashboard/api/accountSubscription';
import Button from 'dashboard/components-next/button/Button.vue';
import AddOnList from './components/AddOnList.vue';
import BillingTabs from './components/BillingTabs.vue';
import PlanSummary from './components/PlanSummary.vue';
import ProductUsageCard from './components/ProductUsageCard.vue';
import TrialBanner from './components/TrialBanner.vue';
import SubscriptionDetails from './SubscriptionDetails.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';

const { t, locale } = useI18n();
const { checkPermissions } = usePolicy();
const { billing, loading, loadFailed, refresh } = useAccountSubscription();
const canManage = computed(() => checkPermissions(['administrator']));
onMounted(() => refresh());
const paymentFailed = ref(false);
const paymentAction = ref('');
const busy = ref(false);
const interval = ref('month');

const date = value =>
  new Date(value).toLocaleDateString(locale.value, {
    day: 'numeric',
    month: 'short',
  });
const money = cents =>
  new Intl.NumberFormat(locale.value, {
    style: 'currency',
    currency: billing.value.currency,
  }).format(cents / 100);

// Trial limits and pauses are explained by the trial banner; this covers paid accounts.
const paidWarning = computed(() => {
  if (billing.value?.trial_enabled || !billing.value?.warning) return '';
  return billing.value.consumed >= billing.value.monthly_limit
    ? t('ACCOUNT_SUBSCRIPTION.PAID_LIMIT_REACHED')
    : t('ACCOUNT_SUBSCRIPTION.PAID_WARNING');
});

const products = computed(() => {
  const usage = billing.value?.products;
  if (!usage) return [];
  const ai = usage.ai_conversations;
  return [
    {
      key: 'ai',
      icon: 'i-lucide-sparkles',
      title: t('ACCOUNT_SUBSCRIPTION.PRODUCTS.AI_CONVERSATIONS'),
      ...ai,
      hint:
        ai.period === 'trial'
          ? t('ACCOUNT_SUBSCRIPTION.PRODUCTS.TRIAL_TOTAL')
          : t('ACCOUNT_SUBSCRIPTION.PRODUCTS.RESETS', {
              date: date(billing.value.quota_resets_at),
            }),
    },
    {
      key: 'agents',
      icon: 'i-lucide-users',
      title: t('ACCOUNT_SUBSCRIPTION.PRODUCTS.AGENTS'),
      ...usage.agents,
      hint: t('ACCOUNT_SUBSCRIPTION.PRODUCTS.IN_USE'),
    },
    {
      key: 'inboxes',
      icon: 'i-lucide-inbox',
      title: t('ACCOUNT_SUBSCRIPTION.PRODUCTS.INBOXES'),
      ...usage.inboxes,
      hint: t('ACCOUNT_SUBSCRIPTION.PRODUCTS.IN_USE'),
    },
    {
      key: 'documents',
      icon: 'i-lucide-book-open',
      title: t('ACCOUNT_SUBSCRIPTION.PRODUCTS.DOCUMENTS'),
      ...usage.documents,
      hint: t('ACCOUNT_SUBSCRIPTION.PRODUCTS.IN_USE'),
    },
  ];
});

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
        :title="t('ACCOUNT_SUBSCRIPTION.BILLING_TITLE')"
        :description="t('ACCOUNT_SUBSCRIPTION.DESCRIPTION')"
      >
        <template #tabs>
          <BillingTabs />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <div
        v-if="loadFailed"
        class="mb-4 flex items-center justify-between gap-4 rounded-xl border border-n-weak bg-n-solid-1 p-4"
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
      <div v-if="billing" class="flex flex-col gap-5">
        <TrialBanner v-if="billing.trial_enabled" :billing="billing" />
        <div
          v-else-if="paidWarning"
          class="flex items-start gap-3 rounded-xl border border-n-amber-6 bg-n-amber-2 px-4 py-3 text-n-amber-11"
          role="status"
        >
          <span
            class="i-lucide-circle-alert mt-0.5 size-4 shrink-0"
            aria-hidden="true"
          />
          <p class="m-0 text-sm">{{ paidWarning }}</p>
        </div>
        <PlanSummary :billing="billing" />
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
          <ProductUsageCard
            v-for="product in products"
            :key="product.key"
            :icon="product.icon"
            :title="product.title"
            :used="product.used"
            :limit="product.limit"
            :hint="product.hint"
          />
        </div>
        <AddOnList
          v-if="billing.plan?.add_ons.length"
          :add-ons="billing.plan.add_ons"
          :currency="billing.plan.currency"
        />
        <SubscriptionDetails
          v-if="canManage && billing.enabled"
          v-model:interval="interval"
          :billing="billing"
          :busy="busy"
          :payment-failed="paymentFailed && paymentAction !== 'payment'"
          @pay="pay"
          @refresh="refresh()"
        />
        <section
          v-if="canManage && billing.can_pay_customization"
          class="flex flex-col justify-between gap-4 rounded-xl border border-n-weak bg-n-solid-1 p-5 sm:flex-row sm:items-center"
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
      </div>
    </template>
  </SettingsLayout>
</template>

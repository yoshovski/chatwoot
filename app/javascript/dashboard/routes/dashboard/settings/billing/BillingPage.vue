<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAccountSubscription } from 'dashboard/composables/useAccountSubscription';
import api from 'dashboard/api/accountSubscription';
import Button from 'dashboard/components-next/button/Button.vue';
import PageHeader from 'dashboard/components-next/kit/PageHeader.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import AddOnList from './components/AddOnList.vue';
import AutoTopUpCard from './components/AutoTopUpCard.vue';
import BillingAlert from './components/BillingAlert.vue';
import InvoicesCard from './components/InvoicesCard.vue';
import OverviewCard from './components/OverviewCard.vue';
import PlanPickerDialog from './components/PlanPickerDialog.vue';
import { useBillingView } from './useBillingView';

// Billing: plan and AI usage side by side, what happens at the limit, then invoices. Administrators only (route).
const { t } = useI18n();
const { billing, loading, loadFailed, refresh } = useAccountSubscription();
onMounted(() => refresh());

const busy = ref(false);
const buying = ref(false);
const pickerError = ref(false);
const picker = ref(null);

const canBuy = computed(() => Boolean(billing.value?.top_up?.available));
const { alert, liveSubscription, canceling } = useBillingView(billing);
// At the limit the alert owns the buy button; the usage card does not repeat it.
const canBuyInCard = computed(
  () => canBuy.value && alert.value?.action !== 'buy'
);
const showAutoTopUp = computed(
  () =>
    !billing.value.trial_enabled &&
    (canBuy.value || billing.value.top_up?.auto.enabled)
);
const canCancel = computed(
  () =>
    liveSubscription.value && !canceling.value && billing.value.can_manage
);
const money = (cents, currency) =>
  new Intl.NumberFormat(undefined, { style: 'currency', currency }).format(
    cents / 100
  );

// Stripe pages (Checkout, portal, an invoice to confirm) open in the same tab and come back to Billing.
const go = async (request, { onError } = {}) => {
  busy.value = true;
  try {
    const { data } = await request();
    if (data.url) {
      window.location.assign(data.url);
      return data;
    }
    await refresh();
    return data;
  } catch {
    if (onError) onError();
    else useAlert(t('BILLING_PAGE.PAYMENT_ERROR'));
    await refresh();
    return null;
  } finally {
    busy.value = false;
  }
};
const openPortal = () => go(() => api.portal());

// One request id per click: a double submit or a retried request charges once.
const requestId = () =>
  window.crypto?.randomUUID?.() ||
  `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
const buyPack = async () => {
  buying.value = true;
  try {
    const { data } = await api.topUp(requestId());
    if (data.url) {
      window.location.assign(data.url);
      return;
    }
    useAlert(
      t(
        data.status === 'paid'
          ? 'BILLING_PAGE.TOP_UP.PAID'
          : 'BILLING_PAGE.TOP_UP.PROCESSING'
      )
    );
    await refresh();
  } catch (error) {
    useAlert(
      t(
        error?.response?.status === 422
          ? 'BILLING_PAGE.TOP_UP.DECLINED'
          : 'BILLING_PAGE.TOP_UP.ERROR'
      )
    );
  } finally {
    buying.value = false;
  }
};

// A custom deal (a saved price, no plan) goes straight to Checkout; everyone else picks a plan.
const openPlans = () => {
  const b = billing.value;
  if (!b.plan && b.monthly_price_cents && b.can_checkout) {
    go(() => api.checkout(b.billing_interval || 'month'));
    return;
  }
  pickerError.value = false;
  picker.value.open();
};
const choosePlan = async ({ plan, interval }) => {
  pickerError.value = false;
  const live =
    billing.value.has_subscription &&
    !['canceled', 'incomplete_expired'].includes(billing.value.payment_status);
  const data = await go(
    () =>
      live
        ? api.changePlan(plan.id, interval)
        : api.checkout(interval, plan.id),
    {
      onError: () => {
        pickerError.value = true;
      },
    }
  );
  if (!data || data.url) return;
  picker.value.close();
  if (data.status === 'scheduled')
    useAlert(t('BILLING_PAGE.PICKER.SCHEDULED'));
  else if (data.status === 'changed') useAlert(t('BILLING_PAGE.PICKER.CHANGED'));
};
const keepPlan = () =>
  go(() =>
    api.changePlan(
      billing.value.plan.id,
      billing.value.stripe_details?.interval || billing.value.billing_interval
    )
  );
const contactUs = () => window.$chatwoot?.toggle?.('open');

const onAlert = action =>
  ({
    retry: () => refresh(),
    portal: openPortal,
    buy: buyPack,
    plans: openPlans,
  })[action]?.();
</script>

<template>
  <div class="flex w-full min-w-0 flex-col gap-5 py-4">
    <PageHeader :title="t('BILLING_PAGE.TITLE')" />

    <div
      v-if="loading"
      class="flex items-center justify-center gap-2 py-16 text-sm text-n-slate-11"
    >
      <Spinner />
      {{ t('BILLING_PAGE.LOADING') }}
    </div>
    <div
      v-else-if="loadFailed && !billing"
      class="flex flex-wrap items-center justify-between gap-3 rounded-card bg-n-solid-2 p-5 shadow-card"
      role="alert"
    >
      <p class="mb-0 text-sm text-n-slate-11">
        {{ t('BILLING_PAGE.LOAD_ERROR') }}
      </p>
      <Button
        :label="t('BILLING_PAGE.RETRY')"
        size="sm"
        variant="outline"
        color="slate"
        @click="refresh()"
      />
    </div>

    <template v-else-if="billing">
      <BillingAlert
        :billing="billing"
        :busy="busy || buying"
        @action="onAlert"
      />

      <OverviewCard
        :billing="billing"
        :busy="busy"
        :can-buy="canBuyInCard"
        :buying="buying"
        @plans="openPlans"
        @portal="openPortal"
        @keep="keepPlan"
        @contact="contactUs"
        @buy="buyPack"
      />

      <AutoTopUpCard
        v-if="showAutoTopUp"
        :billing="billing"
        @refresh="refresh()"
      />

      <section
        v-if="billing.can_pay_customization"
        class="flex flex-wrap items-center justify-between gap-4 rounded-card bg-n-solid-2 px-6 py-4 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
      >
        <p class="mb-0 text-sm text-n-slate-12">
          {{
            billing.custom_payment_description ||
            t('BILLING_PAGE.CUSTOMIZATION')
          }}
          ·
          <span class="font-semibold tabular-nums">{{
            money(billing.custom_payment_cents, billing.currency)
          }}</span>
        </p>
        <Button
          :label="t('BILLING_PAGE.PAY_NOW')"
          size="sm"
          :is-loading="busy"
          :disabled="busy"
          @click="go(() => api.payment())"
        />
      </section>

      <AddOnList
        v-if="billing.plan?.add_ons?.length"
        :add-ons="billing.plan.add_ons"
        :currency="billing.plan.currency"
      />

      <InvoicesCard v-if="billing.can_manage" @portal="openPortal" />

      <!-- Cancelling stays one readable click away; T09 replaces the portal with its own flow. -->
      <button
        v-if="canCancel"
        type="button"
        class="mb-16 self-start text-sm text-n-slate-11 underline underline-offset-4 hover:text-n-slate-12 sm:mb-0"
        :disabled="busy"
        @click="openPortal"
      >
        {{ t('BILLING_PAGE.CANCEL_PLAN') }}
      </button>

      <PlanPickerDialog
        ref="picker"
        :billing="billing"
        :busy="busy"
        :error="pickerError"
        @choose="choosePlan"
      />
    </template>
  </div>
</template>

<script setup>
import { computed, ref, toRef } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { useBillingView } from '../useBillingView';

// The plans side by side with a monthly/annual switch. Without a live subscription every plan goes to Checkout;
// with one, an upgrade applies now and a downgrade at the end of the paid period (AccountPlanChangeService).
const props = defineProps({
  billing: { type: Object, required: true },
  busy: { type: Boolean, default: false },
  error: { type: Boolean, default: false },
});
const emit = defineEmits(['choose']);
const { t } = useI18n();
const { money, date, liveSubscription, trial, pending } = useBillingView(
  toRef(props, 'billing')
);

const dialog = ref(null);
const interval = ref('month');
const currentId = computed(() => props.billing.plan?.id);
const currentInterval = computed(
  () => props.billing.stripe_details?.interval || props.billing.billing_interval
);
const currentRank = computed(
  () => props.billing.plan?.monthly_price_cents ?? 0
);
const plans = computed(() =>
  (props.billing.plans || []).filter(plan => plan.monthly_price_cents > 0)
);
const savings = plan =>
  plan.annual_price_cents
    ? plan.monthly_price_cents * 12 - plan.annual_price_cents
    : 0;
const annualAvailable = computed(() =>
  plans.value.some(plan => plan.annual_price_cents)
);
// "2 months free" only when the prices say so.
const bestSaving = computed(() => {
  const months = Math.max(
    0,
    ...plans.value.map(plan =>
      Math.floor(savings(plan) / plan.monthly_price_cents)
    )
  );
  return months
    ? t('BILLING_PAGE.PICKER.MONTHS_FREE', { count: months }, months)
    : '';
});

const action = plan => {
  if (!liveSubscription.value)
    return { label: t('BILLING_PAGE.PICKER.CHOOSE'), solid: true };
  if (plan.id === currentId.value) {
    if (interval.value !== currentInterval.value)
      return {
        label: t(
          interval.value === 'year'
            ? 'BILLING_PAGE.PICKER.SWITCH_ANNUAL'
            : 'BILLING_PAGE.PICKER.SWITCH_MONTHLY'
        ),
        solid: interval.value === 'year',
      };
    if (pending.value)
      return {
        label: t('BILLING_PAGE.KEEP_PLAN', { plan: plan.name }),
        solid: false,
      };
    return null;
  }
  return plan.monthly_price_cents > currentRank.value
    ? { label: t('BILLING_PAGE.PICKER.UPGRADE'), solid: true }
    : {
        label: t('BILLING_PAGE.PICKER.DOWNGRADE'),
        solid: false,
        note: props.billing.period_ends_at
          ? t('BILLING_PAGE.PICKER.FROM_DATE', {
              date: date(props.billing.period_ends_at),
            })
          : '',
      };
};

const open = () => {
  interval.value = currentInterval.value === 'year' ? 'year' : 'month';
  dialog.value.open();
};
const close = () => dialog.value?.close();
defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialog"
    width="5xl"
    :title="t(liveSubscription ? 'BILLING_PAGE.CHANGE_PLAN' : 'BILLING_PAGE.CHOOSE_PLAN')"
    :show-confirm-button="false"
    :cancel-button-label="t('BILLING_PAGE.PICKER.CLOSE')"
  >
    <div class="flex flex-col gap-4">
      <div
        v-if="annualAvailable"
        class="inline-flex self-start rounded-full bg-n-alpha-2 p-1 text-sm font-medium"
        role="radiogroup"
        :aria-label="t('BILLING_PAGE.PICKER.INTERVAL')"
      >
        <button
          v-for="option in ['month', 'year']"
          :key="option"
          type="button"
          role="radio"
          :aria-checked="interval === option"
          class="inline-flex items-center gap-2 rounded-full px-3 py-1"
          :class="
            interval === option
              ? 'bg-n-solid-2 text-n-slate-12 shadow-card'
              : 'text-n-slate-11'
          "
          @click="interval = option"
        >
          {{
            t(
              option === 'year'
                ? 'BILLING_PAGE.PICKER.ANNUAL'
                : 'BILLING_PAGE.PICKER.MONTHLY'
            )
          }}
          <span
            v-if="option === 'year' && bestSaving"
            class="rounded-full bg-n-teal-3 px-2 py-0.5 text-xs text-n-teal-11"
          >
            {{ bestSaving }}
          </span>
        </button>
      </div>

      <p
        v-if="billing.founder_plan && liveSubscription"
        class="mb-0 flex items-start gap-2 rounded-xl bg-n-amber-3 px-3 py-2 text-sm text-n-amber-11"
      >
        <span class="i-lucide-star mt-0.5 size-4 shrink-0" aria-hidden="true" />
        {{ t('BILLING_PAGE.PICKER.FOUNDER_NOTE') }}
      </p>
      <p
        v-if="error"
        class="mb-0 text-sm text-n-ruby-11"
        role="alert"
      >
        {{ t('BILLING_PAGE.PAYMENT_ERROR') }}
      </p>

      <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        <article
          v-for="plan in plans"
          :key="plan.id"
          class="flex flex-col gap-3 rounded-card p-5 outline -outline-offset-1"
          :class="
            plan.id === currentId
              ? 'bg-n-blue-2 outline-2 outline-n-brand'
              : 'bg-n-solid-2 outline-1 outline-n-container'
          "
        >
          <div class="flex items-center justify-between gap-2">
            <h3 class="mb-0 text-base font-semibold text-n-slate-12">
              {{ plan.name }}
            </h3>
            <span
              v-if="plan.id === currentId"
              class="rounded-full bg-n-blue-3 px-2 py-0.5 text-xs font-medium text-n-blue-11"
            >
              {{
                t(trial ? 'BILLING_PAGE.PICKER.IN_TRIAL' : 'BILLING_PAGE.PICKER.CURRENT')
              }}
            </span>
          </div>
          <div>
            <p
              class="mb-0 font-display text-2xl font-semibold tracking-display tabular-nums text-n-slate-12"
            >
              {{
                money(
                  interval === 'year'
                    ? plan.annual_price_cents
                    : plan.monthly_price_cents,
                  plan.currency
                )
              }}<span class="text-sm font-normal text-n-slate-11">{{
                t(interval === 'year' ? 'BILLING_PAGE.PER_YEAR' : 'BILLING_PAGE.PER_MONTH')
              }}</span>
            </p>
            <p
              v-if="interval === 'year' && savings(plan) > 0"
              class="mb-0 text-xs text-n-teal-11"
            >
              {{
                t('BILLING_PAGE.PICKER.SAVE', {
                  amount: money(savings(plan), plan.currency),
                })
              }}
            </p>
          </div>
          <ul class="m-0 flex list-none flex-col gap-1 p-0 text-sm text-n-slate-11">
            <li>
              {{
                t(
                  'BILLING_PAGE.PICKER.AI',
                  { count: plan.ai_conversations_limit },
                  plan.ai_conversations_limit
                )
              }}
            </li>
            <li v-if="plan.agents_limit">
              {{
                t('BILLING_PAGE.PICKER.TEAM', {
                  agents: plan.agents_limit,
                  inboxes: plan.inboxes_limit,
                })
              }}
            </li>
          </ul>
          <div class="mt-auto flex flex-col gap-1 pt-1">
            <Button
              v-if="action(plan)"
              :label="action(plan).label"
              size="sm"
              :variant="action(plan).solid ? 'solid' : 'ghost'"
              :color="action(plan).solid ? 'blue' : 'slate'"
              :disabled="busy"
              :is-loading="busy"
              class="w-full"
              @click="emit('choose', { plan, interval })"
            />
            <span v-if="action(plan)?.note" class="text-center text-xs text-n-slate-11">
              {{ action(plan).note }}
            </span>
          </div>
        </article>
      </div>
    </div>
  </Dialog>
</template>

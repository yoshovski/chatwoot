<script setup>
import { computed, toRef } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import Button from 'dashboard/components-next/button/Button.vue';
import StatusPill from 'dashboard/components-next/kit/StatusPill.vue';
import { useBillingView } from '../useBillingView';

// The plan and its AI allowance in one card: what you are on, what you pay, how much is left.
const props = defineProps({
  billing: { type: Object, required: true },
  busy: { type: Boolean, default: false },
  canBuy: { type: Boolean, default: false },
  buying: { type: Boolean, default: false },
});
// plans: the plan picker; portal: Stripe's page for the card; keep: drop a pending downgrade; contact: support chat;
// buy: one pack of extra conversations.
const emit = defineEmits(['plans', 'portal', 'keep', 'contact', 'buy']);
const { t } = useI18n();
const { accountScopedRoute } = useAccount();
const {
  planName,
  price,
  cadence,
  status,
  planLine,
  card,
  pending,
  liveSubscription,
  trial,
  free,
  included,
  used,
  extraLeft,
  noAi,
  usedPercent,
  periodLabel,
  pace,
  packLabel,
  date,
} = useBillingView(toRef(props, 'billing'));

const canPick = computed(
  () =>
    props.billing.can_change_plan ||
    (!liveSubscription.value &&
      (props.billing.can_buy_plan || props.billing.can_checkout))
);
// A founder or custom price is not a plan price, so it cannot move to another plan from here. Other reasons a
// plan cannot change (a failed payment, a change waiting for confirmation) show no button at all.
const contactToChange = computed(
  () => Boolean(props.billing.custom_price) && !props.billing.can_change_plan
);
const WARN_AT = 90;
const barClass = computed(() =>
  usedPercent.value >= WARN_AT ? 'bg-n-ruby-9' : 'bg-n-brand'
);
const includedShare = computed(() => {
  const total = included.value + extraLeft.value;
  return total ? Math.max(60, (included.value / total) * 100) : 100;
});
const PACE_TONES = {
  amber: 'text-n-amber-11',
  ruby: 'text-n-ruby-11',
  slate: 'text-n-slate-11',
};
</script>

<template>
  <section
    class="flex min-w-0 flex-col rounded-card bg-n-solid-2 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
  >
    <div class="flex flex-wrap items-start justify-between gap-4 p-6">
      <div class="flex min-w-0 flex-col gap-1">
        <div class="flex flex-wrap items-center gap-2">
          <h2
            class="mb-0 font-display text-2xl font-semibold tracking-display text-n-slate-12"
          >
            {{ planName }}
          </h2>
          <span
            v-if="billing.founder_plan"
            class="inline-flex items-center gap-1 rounded-full bg-n-amber-3 px-2 py-0.5 text-xs font-medium text-n-amber-11"
          >
            <span class="i-lucide-star size-3" aria-hidden="true" />
            {{ t('BILLING_PAGE.FOUNDER') }}
          </span>
          <StatusPill v-if="status" :status="status.tone" :label="status.label" />
        </div>
        <p class="mb-0 text-sm text-n-slate-11">
          <span v-if="!free" class="tabular-nums text-n-slate-12">
            {{ price }}{{ cadence }}
          </span>
          <template v-if="planLine">
            <span v-if="!free"> · </span>{{ planLine }}
          </template>
          <template v-if="card">
            · {{ card }}
            <button
              type="button"
              class="ms-1 inline p-0 align-baseline font-medium text-n-blue-11 hover:underline"
              :disabled="busy"
              @click="emit('portal')"
            >
              {{ t('BILLING_PAGE.UPDATE') }}
            </button>
          </template>
        </p>
        <p v-if="pending" class="mb-0 text-sm text-n-amber-11">
          {{
            t('BILLING_PAGE.PENDING_CHANGE', {
              plan: pending.plan_name,
              date: date(pending.effective_at),
            })
          }}
          ·
          <button
            type="button"
            class="inline p-0 align-baseline font-medium text-n-blue-11 hover:underline"
            :disabled="busy"
            @click="emit('keep')"
          >
            {{ t('BILLING_PAGE.UNDO') }}
          </button>
        </p>
      </div>
      <Button
        v-if="canPick"
        :label="
          t(
            liveSubscription
              ? 'BILLING_PAGE.CHANGE_PLAN'
              : 'BILLING_PAGE.CHOOSE_PLAN'
          )
        "
        :variant="liveSubscription ? 'outline' : 'solid'"
        :color="liveSubscription ? 'slate' : 'blue'"
        size="sm"
        :disabled="busy"
        @click="emit('plans')"
      />
      <Button
        v-else-if="contactToChange"
        :label="t('BILLING_PAGE.CONTACT_TO_CHANGE')"
        variant="outline"
        color="slate"
        size="sm"
        @click="emit('contact')"
      />
    </div>

    <div
      v-if="!noAi"
      class="flex flex-col gap-3 border-t border-n-weak p-6"
    >
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex flex-wrap items-baseline gap-x-3 gap-y-1">
          <p
            class="mb-0 font-display text-3xl font-semibold tracking-display tabular-nums text-n-slate-12"
          >
            {{ used }}<span class="text-n-slate-10"> / {{ included }}</span>
          </p>
          <span class="text-sm text-n-slate-11">
            {{ t(trial ? 'BILLING_PAGE.AI_IN_TRIAL' : 'BILLING_PAGE.AI') }}
          </span>
          <span
            v-if="extraLeft"
            class="rounded-full bg-n-teal-3 px-2 py-0.5 text-xs font-medium text-n-teal-11"
          >
            {{ t('BILLING_PAGE.EXTRA', { count: extraLeft }) }}
          </span>
        </div>
        <Button
          v-if="canBuy"
          :label="packLabel"
          size="sm"
          variant="ghost"
          color="blue"
          icon="i-lucide-plus"
          :is-loading="buying"
          :disabled="buying"
          @click="emit('buy')"
        />
      </div>
      <div class="flex h-2 w-full gap-1">
        <div
          class="h-full overflow-hidden rounded-full bg-n-alpha-2"
          :style="{ width: `${includedShare}%` }"
          role="progressbar"
          :aria-valuenow="usedPercent"
          aria-valuemin="0"
          aria-valuemax="100"
          :aria-label="t('BILLING_PAGE.AI')"
        >
          <div
            class="h-full rounded-full transition-all duration-300"
            :class="barClass"
            :style="{ width: `${usedPercent}%` }"
          />
        </div>
        <div v-if="extraLeft" class="h-full flex-1 rounded-full bg-n-teal-6" />
      </div>
      <div class="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs">
        <span
          v-if="pace"
          class="inline-flex items-center gap-1"
          :class="PACE_TONES[pace.tone]"
        >
          <span :class="pace.icon" class="size-3.5" aria-hidden="true" />
          {{ pace.text }}
        </span>
        <span class="ms-auto text-n-slate-11">{{ periodLabel }}</span>
        <router-link
          :to="accountScopedRoute('billing_settings_usage')"
          class="text-xs font-medium text-n-blue-11 hover:underline"
        >
          {{ t('BILLING_PAGE.DAILY_USAGE') }}
        </router-link>
      </div>
    </div>
  </section>
</template>

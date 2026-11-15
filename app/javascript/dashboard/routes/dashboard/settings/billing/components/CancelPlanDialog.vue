<script setup>
import { computed, ref, toRef } from 'vue';
import { useI18n } from 'vue-i18n';
import api from 'dashboard/api/accountSubscription';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { useBillingView } from '../useBillingView';
import Button from 'dashboard/components-next/button/Button.vue';
const props = defineProps({ billing: { type: Object, required: true } });
const emit = defineEmits(['changed']);
const { t } = useI18n();
const SEPARATOR = ' · ';
const reason = ref('');
const feature = ref('');
const months = ref(3);
const outcome = ref('');
const reasons = ['expensive', 'unused', 'feature', 'quality', 'other'];
const labels = computed(() => ({
  expensive: t('BILLING_PAGE.CANCEL_FLOW.REASONS.expensive'),
  unused: t('BILLING_PAGE.CANCEL_FLOW.REASONS.unused'),
  feature: t('BILLING_PAGE.CANCEL_FLOW.REASONS.feature'),
  quality: t('BILLING_PAGE.CANCEL_FLOW.REASONS.quality'),
  other: t('BILLING_PAGE.CANCEL_FLOW.REASONS.other'),
}));
const offers = computed(() => ({
  expensive: {
    title: t('BILLING_PAGE.CANCEL_FLOW.OFFERS.expensive.TITLE'),
    description: t('BILLING_PAGE.CANCEL_FLOW.OFFERS.expensive.DESCRIPTION'),
    action: t('BILLING_PAGE.CANCEL_FLOW.OFFERS.expensive.ACTION'),
  },
  unused: {
    title: t('BILLING_PAGE.CANCEL_FLOW.OFFERS.unused.TITLE'),
    description: t('BILLING_PAGE.CANCEL_FLOW.OFFERS.unused.DESCRIPTION'),
    action: t('BILLING_PAGE.CANCEL_FLOW.OFFERS.unused.ACTION'),
  },
  feature: {
    title: t('BILLING_PAGE.CANCEL_FLOW.OFFERS.feature.TITLE'),
    description: t('BILLING_PAGE.CANCEL_FLOW.OFFERS.feature.DESCRIPTION'),
    action: t('BILLING_PAGE.CANCEL_FLOW.OFFERS.feature.ACTION'),
  },
  quality: {
    title: t('BILLING_PAGE.CANCEL_FLOW.OFFERS.quality.TITLE'),
    description: t('BILLING_PAGE.CANCEL_FLOW.OFFERS.quality.DESCRIPTION'),
    action: t('BILLING_PAGE.CANCEL_FLOW.OFFERS.quality.ACTION'),
  },
  other: {
    title: t('BILLING_PAGE.CANCEL_FLOW.OFFERS.other.TITLE'),
    description: t('BILLING_PAGE.CANCEL_FLOW.OFFERS.other.DESCRIPTION'),
    action: t('BILLING_PAGE.CANCEL_FLOW.OFFERS.other.ACTION'),
  },
}));
const icons = {
  expensive: 'i-lucide-wallet',
  unused: 'i-lucide-circle-pause',
  feature: 'i-lucide-puzzle',
  quality: 'i-lucide-message-circle-question',
  other: 'i-lucide-ellipsis',
};
const offer = computed(() => offers.value[reason.value]);
const dialog = ref(null);
const attempt = ref(null);
const loading = ref(false);
const busy = ref(false);
const failed = ref(false);
const chosenPlan = ref(null);
const { date, money } = useBillingView(toRef(props, 'billing'));
const endDate = computed(() =>
  date(attempt.value?.period_ends_at || props.billing.period_ends_at)
);
const available = computed(() => {
  if (reason.value === 'expensive') return attempt.value?.discount_available;
  if (reason.value === 'unused') return attempt.value?.pause_available;
  if (reason.value === 'feature')
    return attempt.value?.smaller_plans.length > 0;
  return reason.value === 'quality';
});
const outcomeText = computed(() => ({
  canceled: t('BILLING_PAGE.CANCEL_FLOW.SUCCESS_DESCRIPTION', {
    date: endDate.value,
  }),
  discounted: t('BILLING_PAGE.CANCEL_FLOW.DISCOUNTED'),
  paused: t('BILLING_PAGE.CANCEL_FLOW.PAUSED'),
  downgraded: t('BILLING_PAGE.CANCEL_FLOW.DOWNGRADED'),
  setup_requested: t('BILLING_PAGE.CANCEL_FLOW.SETUP_REQUESTED'),
}));
const load = async () => {
  loading.value = true;
  failed.value = false;
  try {
    const { data } = await api.startCancellation();
    attempt.value = data;
    chosenPlan.value = data.smaller_plans[0]?.id;
  } catch {
    failed.value = true;
  } finally {
    loading.value = false;
  }
};
const open = () => {
  reason.value = '';
  feature.value = '';
  months.value = 3;
  outcome.value = '';
  attempt.value = null;
  dialog.value.open();
  load();
};
const close = async () => {
  if (busy.value) return;
  if (attempt.value && !outcome.value) {
    busy.value = true;
    try {
      await api.dismissCancellation(attempt.value.id, {
        reason: reason.value || 'other',
        feature: feature.value,
      });
    } catch {
      failed.value = true;
      return;
    } finally {
      busy.value = false;
    }
  }
  dialog.value.close();
};
const decide = async accept => {
  busy.value = true;
  failed.value = false;
  const decision = {
    reason: reason.value || 'other',
    feature: feature.value,
    months: months.value,
    plan_id: chosenPlan.value,
  };
  try {
    const { data } = await (accept
      ? api.acceptRetention(attempt.value.id, decision)
      : api.cancelPlan(attempt.value.id, decision));
    outcome.value = data.status;
    emit('changed');
  } catch {
    failed.value = true;
  } finally {
    busy.value = false;
  }
};
defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialog"
    width="2xl"
    :title="t('BILLING_PAGE.CANCEL_FLOW.TITLE')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    overflow-y-auto
  >
    <div class="flex max-h-[75dvh] flex-col gap-6 overflow-hidden">
      <div
        v-if="loading"
        class="flex justify-center gap-2 py-8 text-sm text-n-slate-11"
        role="status"
      >
        <Spinner />{{ t('BILLING_PAGE.LOADING') }}
      </div>
      <div
        v-if="failed"
        class="flex flex-wrap items-center justify-between gap-3 rounded-xl bg-n-ruby-3 p-3 text-sm text-n-ruby-11"
        role="alert"
      >
        {{ t('BILLING_PAGE.CANCEL_FLOW.ERROR') }}
        <Button
          v-if="!attempt"
          :label="t('BILLING_PAGE.RETRY')"
          size="sm"
          @click="load"
        />
      </div>
      <div
        v-if="outcome"
        class="flex flex-col items-center gap-3 py-8 text-center"
        role="status"
      >
        <span
          class="i-lucide-circle-check size-10 text-n-teal-10"
          aria-hidden="true"
        />
        <h2 class="mb-0 font-display text-xl font-semibold text-n-slate-12">
          {{
            outcome === 'canceled'
              ? t('BILLING_PAGE.CANCEL_FLOW.SUCCESS_TITLE')
              : t('BILLING_PAGE.CANCEL_FLOW.ACCEPTED_TITLE')
          }}
        </h2>
        <p class="mb-0 max-w-md text-sm leading-relaxed text-n-slate-11">
          {{ outcomeText[outcome] }}
        </p>
        <Button
          :label="t('BILLING_PAGE.CANCEL_FLOW.BACK')"
          class="mt-4"
          @click="close"
        />
      </div>
      <template v-else-if="attempt">
        <div class="flex min-h-0 flex-col gap-6 overflow-y-auto">
          <div class="flex flex-col gap-4">
            <p class="mb-0 text-sm leading-relaxed text-n-slate-11">
              {{ t('BILLING_PAGE.CANCEL_FLOW.DESCRIPTION') }}
            </p>
            <div
              class="grid gap-2 sm:grid-cols-2"
              role="group"
              :aria-label="t('BILLING_PAGE.CANCEL_FLOW.REASON')"
            >
              <button
                v-for="item in reasons"
                :key="item"
                type="button"
                :disabled="busy"
                :aria-pressed="reason === item"
                class="flex items-center gap-3 rounded-xl px-4 py-3.5 text-start text-sm outline outline-1 -outline-offset-1 transition-colors focus-visible:outline-2 focus-visible:outline-n-brand"
                :class="
                  reason === item
                    ? 'bg-n-blue-2 text-n-blue-11 outline-n-brand'
                    : 'bg-n-solid-2 text-n-slate-12 outline-n-container hover:bg-n-alpha-1'
                "
                @click="reason = item"
              >
                <span
                  class="size-5 shrink-0 text-n-slate-10"
                  :class="icons[item]"
                  aria-hidden="true"
                />
                <span class="flex-1">{{ labels[item] }}</span>
                <span
                  class="size-4 shrink-0"
                  :class="
                    reason === item
                      ? 'i-lucide-circle-check text-n-blue-10'
                      : 'i-lucide-circle text-n-slate-8'
                  "
                  aria-hidden="true"
                />
              </button>
            </div>
          </div>
          <div
            v-if="reason"
            class="flex flex-col gap-4 rounded-card bg-n-blue-2 p-5"
          >
            <div class="flex items-center justify-between gap-3">
              <span class="text-xs font-semibold text-n-blue-11">{{
                t('BILLING_PAGE.CANCEL_FLOW.OFFER')
              }}</span>
            </div>
            <h2
              class="mb-0 font-display text-xl font-semibold tracking-display text-n-slate-12"
            >
              {{ offer.title }}
            </h2>
            <p class="mb-0 text-sm leading-relaxed text-n-slate-11">
              {{
                available || reason === 'other'
                  ? offer.description
                  : t('BILLING_PAGE.CANCEL_FLOW.UNAVAILABLE')
              }}
            </p>
            <label
              v-if="reason === 'feature'"
              class="flex flex-col gap-2 text-sm text-n-slate-12"
            >
              {{ t('BILLING_PAGE.CANCEL_FLOW.FEATURE_LABEL') }}
              <textarea
                v-model="feature"
                :placeholder="t('BILLING_PAGE.CANCEL_FLOW.FEATURE_PLACEHOLDER')"
                maxlength="2000"
                :disabled="busy"
                rows="2"
                class="mb-0 rounded-xl border-n-weak bg-n-solid-2 text-sm"
              />
            </label>
            <label
              v-if="reason === 'unused' && available"
              class="flex flex-col gap-2 text-sm text-n-slate-12"
            >
              {{ t('BILLING_PAGE.CANCEL_FLOW.PAUSE_LABEL') }}
              <select
                v-model="months"
                :disabled="busy"
                class="mb-0 rounded-xl border-n-weak bg-n-solid-2 text-sm"
              >
                <option v-for="count in [1, 2, 3]" :key="count" :value="count">
                  {{ t('BILLING_PAGE.CANCEL_FLOW.MONTHS', { count }, count) }}
                </option>
              </select>
            </label>
            <label
              v-if="reason === 'feature' && available"
              class="flex flex-col gap-2 text-sm text-n-slate-12"
            >
              {{ t('BILLING_PAGE.CANCEL_FLOW.SMALLER_PLAN') }}
              <select
                v-model="chosenPlan"
                :disabled="busy"
                class="mb-0 rounded-xl border-n-weak bg-n-solid-2 text-sm"
              >
                <option
                  v-for="plan in attempt.smaller_plans"
                  :key="plan.id"
                  :value="plan.id"
                >
                  {{ plan.name }}{{ SEPARATOR }}
                  {{
                    money(
                      billing.billing_interval === 'year'
                        ? plan.annual_price_cents
                        : plan.monthly_price_cents,
                      plan.currency
                    )
                  }}{{
                    billing.billing_interval === 'year'
                      ? t('BILLING_PAGE.PER_YEAR')
                      : t('BILLING_PAGE.PER_MONTH')
                  }}
                </option>
              </select>
            </label>
            <Button
              v-if="available"
              :label="offer.action"
              class="self-start"
              :disabled="busy"
              :is-loading="busy"
              @click="decide(true)"
            />
          </div>
        </div>
        <div class="flex shrink-0 flex-col gap-4 border-t border-n-weak pt-5">
          <p class="mb-0 text-xs leading-relaxed text-n-slate-11">
            {{ t('BILLING_PAGE.CANCEL_FLOW.END_NOTE', { date: endDate }) }}
          </p>
          <div class="flex flex-wrap items-center justify-between gap-3">
            <Button
              :label="t('BILLING_PAGE.CANCEL_FLOW.KEEP')"
              color="slate"
              variant="ghost"
              :disabled="busy"
              @click="close"
            />
            <Button
              :label="t('BILLING_PAGE.CANCEL_FLOW.CANCEL')"
              color="ruby"
              variant="outline"
              :disabled="busy"
              :is-loading="busy"
              @click="decide(false)"
            />
          </div>
        </div>
      </template>
    </div>
  </Dialog>
</template>

<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';
import { useAccount } from 'dashboard/composables/useAccount';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { useAccountSubscription } from 'dashboard/composables/useAccountSubscription';
import { useBillingView } from '../useBillingView';

defineProps({ title: { type: String, default: '' } });

const { t } = useI18n();
const { accountScopedRoute } = useAccount();
const { checkPermissions } = usePolicy();
const { billing } = useAccountSubscription();

const safeBilling = computed(() => billing.value || {});
const {
  planName,
  status,
  included,
  used,
  extraLeft,
  noAi,
  usedPercent,
  atLimit,
  periodLabel,
  trial,
  free,
  pastDue,
} = useBillingView(safeBilling);

const SLASH = ' / ';
const isOpen = ref(false);
const canManage = computed(() => checkPermissions(['administrator']));

const showIndicator = computed(
  () =>
    Boolean(
      billing.value &&
        (billing.value.enabled ||
          billing.value.trial_enabled ||
          billing.value.plan ||
          billing.value.ai_replies_paused)
    ) && canManage.value
);

const isPausedOrLimit = computed(
  () =>
    Boolean(billing.value?.ai_replies_paused) || atLimit.value || pastDue.value
);
const isNearLimit = computed(
  () => !isPausedOrLimit.value && included.value > 0 && usedPercent.value >= 80
);

const pillLabel = computed(() => {
  if (pastDue.value) return t('BILLING_PAGE.STATUS.PAST_DUE');
  if (atLimit.value || billing.value?.ai_pause_reason === 'limit_reached') {
    return t('ACCOUNT_SUBSCRIPTION.TOP_BAR.LIMIT_REACHED');
  }
  if (billing.value?.ai_replies_paused) {
    return t('ACCOUNT_SUBSCRIPTION.AI_PAUSED.TITLE');
  }
  if (noAi.value) return planName.value;
  if (included.value > 0) {
    return t('ACCOUNT_SUBSCRIPTION.TOP_BAR.USAGE_PILL', {
      used: used.value,
      limit: included.value,
    });
  }
  return t('ACCOUNT_SUBSCRIPTION.TOP_BAR.UNLIMITED');
});

const pillClasses = computed(() => {
  if (isPausedOrLimit.value) {
    return 'border-n-ruby-6 bg-n-ruby-3 text-n-ruby-11 hover:bg-n-ruby-4';
  }
  if (isNearLimit.value) {
    return 'border-n-amber-6 bg-n-amber-3 text-n-amber-11 hover:bg-n-amber-4';
  }
  return 'border-n-strong/80 bg-n-solid-2 text-n-slate-12 hover:bg-n-slate-2';
});

const pillIcon = computed(() => {
  if (isPausedOrLimit.value) return 'i-lucide-circle-alert';
  if (isNearLimit.value) return 'i-lucide-zap text-n-amber-11';
  return 'i-lucide-sparkles text-n-blue-11';
});

const barColorClass = computed(() => {
  if (isPausedOrLimit.value) return 'bg-n-ruby-9';
  if (isNearLimit.value) return 'bg-n-amber-9';
  return 'bg-n-brand';
});

const showPeriodLabel = computed(() =>
  Boolean(
    (trial.value && billing.value?.trial_ends_at) ||
      (!trial.value && billing.value?.quota_resets_at)
  )
);

const upgradeLabel = computed(() =>
  trial.value ||
  free.value ||
  noAi.value ||
  isPausedOrLimit.value ||
  isNearLimit.value
    ? t('BILLING_PAGE.PICKER.UPGRADE')
    : t('ACCOUNT_SUBSCRIPTION.TOP_BAR.MANAGE_PLAN')
);
</script>

<template>
  <div
    v-if="showIndicator || title"
    class="flex h-11 shrink-0 items-center justify-end border-b border-n-weak bg-n-solid-2"
    :class="title ? 'gap-1.5 px-2.5 sm:gap-2.5 sm:px-4' : 'gap-2.5 px-4'"
  >
    <h1
      v-if="title"
      class="m-0 me-auto min-w-0 truncate font-display text-base font-semibold text-n-slate-12"
    >
      {{ title }}
    </h1>
    <div
      v-if="showIndicator"
      v-on-click-outside="() => (isOpen = false)"
      class="relative shrink-0"
    >
      <button
        type="button"
        class="inline-flex h-7 items-center gap-1.5 rounded-lg border px-2.5 text-xs font-medium shadow-sm transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
        :class="pillClasses"
        :aria-expanded="isOpen"
        :aria-label="t('ACCOUNT_SUBSCRIPTION.TOP_BAR.POPOVER_LABEL')"
        @click="isOpen = !isOpen"
      >
        <span
          :class="[pillIcon, { 'max-sm:hidden': title }]"
          class="size-3.5 shrink-0"
          aria-hidden="true"
        />
        <span class="whitespace-nowrap tabular-nums">{{ pillLabel }}</span>
        <span
          v-if="trial && !isPausedOrLimit"
          class="rounded bg-n-blue-3 px-1.5 py-0.5 text-[10px] font-semibold leading-none text-n-blue-11"
        >
          {{ t('ACCOUNT_SUBSCRIPTION.TOP_BAR.TRIAL_TAG') }}
        </span>
        <span
          class="i-lucide-chevron-down size-3.5 shrink-0 opacity-75 transition-transform"
          :class="{ 'rotate-180': isOpen, 'max-sm:hidden': title }"
          aria-hidden="true"
        />
      </button>

      <div
        v-if="isOpen"
        class="absolute end-0 top-full z-50 mt-1.5 w-72 rounded-card bg-n-solid-2 p-4 shadow-lg outline outline-1 -outline-offset-1 outline-n-container"
      >
        <div class="flex items-center justify-between gap-2">
          <span class="text-sm font-semibold text-n-slate-12">
            {{ planName }}
          </span>
          <span
            v-if="status"
            class="rounded-full bg-n-blue-3 px-2 py-0.5 text-[11px] font-medium text-n-blue-11"
          >
            {{ status.label }}
          </span>
        </div>

        <div v-if="!noAi && included > 0" class="mt-3 flex flex-col gap-1.5">
          <div class="flex items-center justify-between text-xs">
            <span class="text-n-slate-11">{{ t('BILLING_PAGE.AI') }}</span>
            <span class="font-semibold tabular-nums text-n-slate-12">
              {{ used }}{{ SLASH }}{{ included }}
            </span>
          </div>
          <div class="h-2 w-full overflow-hidden rounded-full bg-n-slate-3">
            <div
              class="h-full rounded-full transition-all duration-300"
              :class="barColorClass"
              :style="{ width: `${usedPercent}%` }"
            />
          </div>
        </div>

        <p
          v-if="extraLeft > 0"
          class="mb-0 mt-2 text-xs font-medium text-n-teal-11"
        >
          {{ t('BILLING_PAGE.EXTRA', { count: extraLeft }) }}
        </p>

        <p v-if="showPeriodLabel" class="mb-0 mt-2 text-xs text-n-slate-11">
          {{ periodLabel }}
        </p>

        <div
          class="mt-3 flex items-center justify-between gap-2 border-t border-n-weak pt-3"
        >
          <router-link
            :to="accountScopedRoute('billing_settings_usage')"
            class="text-xs font-medium text-n-slate-11 hover:text-n-blue-11"
            @click="isOpen = false"
          >
            {{ t('ACCOUNT_SUBSCRIPTION.TOP_BAR.VIEW_USAGE') }}
          </router-link>
          <router-link
            :to="accountScopedRoute('billing_settings_index')"
            class="text-xs font-semibold text-n-blue-11 hover:underline"
            @click="isOpen = false"
          >
            {{ t('ACCOUNT_SUBSCRIPTION.TOP_BAR.VIEW_BILLING') }}
          </router-link>
        </div>
      </div>
    </div>

    <router-link
      v-if="showIndicator"
      :to="accountScopedRoute('billing_settings_index')"
      class="inline-flex h-7 shrink-0 items-center gap-1 rounded-lg bg-n-teal-9 px-3 text-xs font-semibold text-white shadow-sm transition-colors hover:bg-n-teal-10 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-teal-9"
    >
      {{ upgradeLabel }}
    </router-link>
  </div>
  <template v-else />
</template>

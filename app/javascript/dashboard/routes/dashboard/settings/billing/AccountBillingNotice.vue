<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useAccount } from 'dashboard/composables/useAccount';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { useAccountSubscription } from 'dashboard/composables/useAccountSubscription';

const { t } = useI18n();
const route = useRoute();
const { accountScopedRoute } = useAccount();
const { checkPermissions } = usePolicy();
const { billing } = useAccountSubscription();
const canManage = computed(() => checkPermissions(['administrator']));
const notice = computed(() => {
  if (billing.value?.ai_replies_paused)
    return t('ACCOUNT_SUBSCRIPTION.PAUSED_NOTICE');
  if (!billing.value?.warning) return '';
  if (billing.value.consumed >= billing.value.monthly_limit)
    return t('ACCOUNT_SUBSCRIPTION.LIMIT_REACHED_NOTICE');
  return t('ACCOUNT_SUBSCRIPTION.LIMIT_NEAR_NOTICE');
});
</script>

<template>
  <div
    v-if="billing?.enabled && notice && route.name !== 'billing_settings_index'"
    class="flex shrink-0 flex-wrap items-center gap-x-3 gap-y-1 border-b border-n-amber-6 bg-n-amber-2 px-6 py-2 text-sm text-n-amber-11"
    role="status"
  >
    <span class="i-lucide-circle-alert size-4 shrink-0" aria-hidden="true" />
    <span>{{ notice }}</span>
    <RouterLink
      v-if="canManage"
      :to="accountScopedRoute('billing_settings_index')"
      class="ms-auto font-medium underline underline-offset-4 hover:text-n-amber-12"
    >
      {{ t('ACCOUNT_SUBSCRIPTION.VIEW_USAGE') }}
    </RouterLink>
  </div>
</template>

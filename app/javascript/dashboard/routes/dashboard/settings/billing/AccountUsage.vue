<script setup>
import { computed, ref, watch } from 'vue';
import { useTimeoutPoll } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { usePolicy } from 'dashboard/composables/usePolicy';
import api from 'dashboard/api/accountSubscription';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({ compact: { type: Boolean, default: false } });
const { t } = useI18n();
const { accountId } = useAccount();
const { checkPermissions } = usePolicy();
const canManage = computed(() => checkPermissions(['administrator']));
const billing = ref(null);
const error = ref('');
const busy = ref(false);
const interval = ref('month');
let generation = 0;
const date = value => (value ? new Date(value).toLocaleDateString() : '—');
const money = cents =>
  new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: billing.value.currency,
  }).format(cents / 100);
const load = async () => {
  const token = generation;
  try {
    const { data } = await api.get();
    if (token === generation) billing.value = data;
  } catch {
    if (token === generation && !props.compact)
      error.value = t('ACCOUNT_SUBSCRIPTION.ERROR');
  }
};
watch(
  accountId,
  () => {
    generation += 1;
    billing.value = null;
    error.value = '';
    load();
  },
  { immediate: true }
);
useTimeoutPoll(load, 30000, { immediate: true });
const pay = async (action = 'checkout') => {
  busy.value = true;
  error.value = '';
  try {
    const { data } = await api[action](interval.value);
    window.location.assign(data.url);
  } catch {
    error.value = t('ACCOUNT_SUBSCRIPTION.ERROR');
  } finally {
    busy.value = false;
  }
};
</script>

<template>
  <section
    v-if="billing?.enabled"
    class="p-4 border rounded-xl border-n-weak bg-n-background text-n-slate-12"
  >
    <details :open="!compact">
      <summary
        class="flex items-center gap-2 cursor-pointer"
        :class="
          billing.warning || billing.ai_replies_paused
            ? 'text-n-amber-11'
            : 'text-n-slate-12'
        "
      >
        <span class="i-lucide-message-circle size-4" />
        <span>{{ t('ACCOUNT_SUBSCRIPTION.CONVERSATIONS') }}</span>
        <span class="ms-auto">{{
          t('ACCOUNT_SUBSCRIPTION.USAGE', {
            used: billing.consumed,
            limit: billing.monthly_limit ?? t('ACCOUNT_SUBSCRIPTION.UNLIMITED'),
          })
        }}</span>
      </summary>
      <div class="flex flex-col gap-3 pt-4">
        <progress
          v-if="billing.monthly_limit > 0"
          class="w-full"
          :value="billing.consumed"
          :max="billing.monthly_limit"
          :aria-label="t('ACCOUNT_SUBSCRIPTION.CONVERSATIONS')"
        />
        <p class="m-0 text-sm text-n-slate-11">
          {{
            t('ACCOUNT_SUBSCRIPTION.RESETS', {
              date: date(billing.quota_resets_at),
            })
          }}
        </p>
        <p class="m-0 text-sm">{{ t('ACCOUNT_SUBSCRIPTION.COUNTING') }}</p>
        <p v-if="billing.warning" class="m-0 text-n-amber-11">
          {{ t('ACCOUNT_SUBSCRIPTION.WARNING') }}
        </p>
        <p v-if="billing.ai_replies_paused" class="m-0 text-n-amber-11">
          {{ t('ACCOUNT_SUBSCRIPTION.PAUSED') }}
        </p>
        <p v-if="billing.trial_enabled" class="m-0">
          {{
            t('ACCOUNT_SUBSCRIPTION.TRIAL_ENDS', {
              date: date(billing.trial_ends_at),
            })
          }}
        </p>
        <template v-if="!compact">
          <p class="m-0">
            {{
              t('ACCOUNT_SUBSCRIPTION.PERIOD', {
                start: date(billing.period_started_at),
                end: date(billing.period_ends_at),
              })
            }}
          </p>
          <p class="m-0">
            {{
              t('ACCOUNT_SUBSCRIPTION.PRICE', {
                monthly: money(billing.monthly_price_cents),
                yearly: money(billing.annual_price_cents),
              })
            }}
          </p>
          <p v-if="billing.setup_fee_cents" class="m-0">
            {{
              t('ACCOUNT_SUBSCRIPTION.SETUP_FEE', {
                amount: money(billing.setup_fee_cents),
              })
            }}
          </p>
          <table v-if="billing.history.length" class="w-full text-sm">
            <thead>
              <tr>
                <th class="text-start">
                  {{ t('ACCOUNT_SUBSCRIPTION.MONTH') }}
                </th>
                <th class="text-end">
                  {{ t('ACCOUNT_SUBSCRIPTION.CONVERSATIONS') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="month in billing.history"
                :key="month.period_started_at"
              >
                <td>{{ date(month.period_started_at) }}</td>
                <td class="text-end">{{ month.consumed }}</td>
              </tr>
            </tbody>
          </table>
        </template>
        <Button
          v-if="canManage && billing.can_pay_customization"
          :label="
            t('ACCOUNT_SUBSCRIPTION.CUSTOM_PAYMENT', {
              amount: money(billing.custom_payment_cents),
              description: billing.custom_payment_description || '',
            })
          "
          :is-loading="busy"
          @click="pay('payment')"
        />
        <div v-if="canManage" class="flex flex-wrap items-center gap-2">
          <template v-if="billing.can_checkout">
            <select
              v-model="interval"
              :aria-label="t('ACCOUNT_SUBSCRIPTION.BILLING_INTERVAL')"
              class="rounded-lg border border-n-weak bg-n-background"
            >
              <option value="month">
                {{ t('ACCOUNT_SUBSCRIPTION.MONTHLY') }}
              </option>
              <option value="year">
                {{ t('ACCOUNT_SUBSCRIPTION.YEARLY') }}
              </option>
            </select>
            <Button
              :label="t('ACCOUNT_SUBSCRIPTION.SUBSCRIBE')"
              :is-loading="busy"
              @click="pay()"
            />
          </template>
          <Button
            v-if="billing.can_manage"
            :label="t('ACCOUNT_SUBSCRIPTION.MANAGE')"
            :is-loading="busy"
            @click="pay('portal')"
          />
        </div>
      </div>
    </details>
    <p v-if="error" class="mt-3 text-n-ruby-11" role="alert">{{ error }}</p>
  </section>
  <p v-else-if="!compact" class="p-4 text-n-slate-11">
    {{ error || t('ACCOUNT_SUBSCRIPTION.NOT_CONFIGURED') }}
  </p>
</template>

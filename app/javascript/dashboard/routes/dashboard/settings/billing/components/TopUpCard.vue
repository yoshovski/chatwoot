<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import api from 'dashboard/api/accountSubscription';
import Button from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

const props = defineProps({
  topUp: { type: Object, required: true },
  extraLeft: { type: Number, default: 0 },
});
const emit = defineEmits(['refresh']);

const { t, locale } = useI18n();
const buying = ref(false);
const saving = ref(false);
// '', 'paid', 'processing', 'declined', 'error', 'settings_error'
const notice = ref('');

const pack = computed(() => props.topUp.pack);
const auto = computed(() => props.topUp.auto);
const history = computed(() => props.topUp.history || []);
const price = computed(() =>
  new Intl.NumberFormat(locale.value, {
    style: 'currency',
    currency: pack.value.currency,
  }).format(pack.value.amount_cents / 100)
);
const date = value =>
  new Date(value).toLocaleDateString(locale.value, {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
const packOptions = computed(() =>
  Array.from({ length: 10 }, (_, index) => ({
    value: index + 1,
    label: t('ACCOUNT_SUBSCRIPTION.TOP_UP.AUTO_MAX_OPTION', {
      count: index + 1,
    }),
  }))
);
const autoFailed = computed(
  () => Boolean(auto.value.failed_at) && !auto.value.enabled
);

const requestId = () =>
  window.crypto?.randomUUID?.() ||
  `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;

const buy = async () => {
  buying.value = true;
  notice.value = '';
  try {
    const { data } = await api.topUp(requestId());
    if (data.url) {
      window.location.assign(data.url);
      return;
    }
    notice.value = data.status === 'paid' ? 'paid' : 'processing';
    emit('refresh');
  } catch (error) {
    notice.value = error?.response?.status === 422 ? 'declined' : 'error';
  } finally {
    buying.value = false;
  }
};

const saveSettings = async changes => {
  saving.value = true;
  notice.value = '';
  try {
    await api.updateTopUpSettings({
      auto_top_up_enabled: auto.value.enabled,
      auto_top_up_max_packs: auto.value.max_packs,
      ...changes,
    });
  } catch {
    notice.value = 'settings_error';
  } finally {
    saving.value = false;
    emit('refresh');
  }
};

const noticeOk = computed(() => ['paid', 'processing'].includes(notice.value));
const historyLabel = entry => {
  const count = Math.abs(entry.amount);
  return {
    purchase: t('ACCOUNT_SUBSCRIPTION.TOP_UP.HISTORY.PURCHASE', { count }),
    adjustment: t('ACCOUNT_SUBSCRIPTION.TOP_UP.HISTORY.ADJUSTMENT', { count }),
    expiry: t('ACCOUNT_SUBSCRIPTION.TOP_UP.HISTORY.EXPIRY', { count }),
  }[entry.reason];
};
const noticeText = computed(
  () =>
    ({
      paid: t('ACCOUNT_SUBSCRIPTION.TOP_UP.NOTICE.PAID'),
      processing: t('ACCOUNT_SUBSCRIPTION.TOP_UP.NOTICE.PROCESSING'),
      declined: t('ACCOUNT_SUBSCRIPTION.TOP_UP.NOTICE.DECLINED'),
      error: t('ACCOUNT_SUBSCRIPTION.TOP_UP.NOTICE.ERROR'),
      settings_error: t('ACCOUNT_SUBSCRIPTION.TOP_UP.NOTICE.SETTINGS_ERROR'),
    })[notice.value] || ''
);
</script>

<template>
  <section
    class="flex flex-col gap-5 rounded-xl border border-n-weak bg-n-solid-1 p-4 sm:p-5"
    data-test-id="top-up-card"
  >
    <div class="flex flex-col justify-between gap-4 sm:flex-row sm:items-start">
      <div class="flex min-w-0 flex-col gap-1">
        <h2 class="m-0 text-base font-semibold text-n-slate-12">
          {{ t('ACCOUNT_SUBSCRIPTION.TOP_UP.TITLE') }}
        </h2>
        <p class="m-0 text-sm text-n-slate-11">
          {{ t('ACCOUNT_SUBSCRIPTION.TOP_UP.LEFT', { count: extraLeft }) }}
        </p>
      </div>
      <Button
        v-if="topUp.available"
        :label="
          t('ACCOUNT_SUBSCRIPTION.TOP_UP.BUY', {
            count: pack.conversations,
            price,
          })
        "
        icon="i-lucide-plus"
        :is-loading="buying"
        :disabled="buying"
        data-test-id="top-up-buy"
        @click="buy"
      />
    </div>

    <p
      v-if="notice"
      class="m-0 text-sm"
      :class="noticeOk ? 'text-n-teal-11' : 'text-n-ruby-11'"
      :role="noticeOk ? 'status' : 'alert'"
      data-test-id="top-up-notice"
    >
      {{ noticeText }}
    </p>

    <div
      v-if="autoFailed"
      class="flex items-start gap-2 rounded-lg bg-n-ruby-2 px-3 py-2 text-sm text-n-ruby-11"
      role="alert"
      data-test-id="top-up-auto-failed"
    >
      <span
        class="i-lucide-circle-alert mt-0.5 size-4 shrink-0"
        aria-hidden="true"
      />
      <p class="m-0">
        {{
          t('ACCOUNT_SUBSCRIPTION.TOP_UP.AUTO_FAILED', {
            date: date(auto.failed_at),
          })
        }}
      </p>
    </div>

    <div
      v-if="topUp.available"
      class="flex flex-col gap-3 border-t border-n-weak pt-4 sm:flex-row sm:items-center sm:justify-between"
    >
      <div class="flex items-start gap-3">
        <Switch
          :model-value="auto.enabled"
          :disabled="saving"
          data-test-id="top-up-auto-switch"
          @update:model-value="
            value => saveSettings({ auto_top_up_enabled: value })
          "
        />
        <div class="flex flex-col gap-0.5">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('ACCOUNT_SUBSCRIPTION.TOP_UP.AUTO_TITLE') }}
          </span>
          <span class="text-sm text-n-slate-11">
            {{
              t('ACCOUNT_SUBSCRIPTION.TOP_UP.AUTO_HELP', {
                threshold: auto.threshold,
                count: pack.conversations,
                price,
              })
            }}
          </span>
          <span v-if="auto.enabled" class="text-xs text-n-slate-10">
            {{
              t('ACCOUNT_SUBSCRIPTION.TOP_UP.AUTO_USED', {
                used: auto.used_this_period,
                max: auto.max_packs,
              })
            }}
          </span>
        </div>
      </div>
      <Select
        :model-value="auto.max_packs"
        :options="packOptions"
        :disabled="saving || !auto.enabled"
        :aria-label="t('ACCOUNT_SUBSCRIPTION.TOP_UP.AUTO_MAX_LABEL')"
        @update:model-value="
          value => saveSettings({ auto_top_up_max_packs: Number(value) })
        "
      />
    </div>

    <div v-if="history.length" class="flex flex-col gap-2">
      <h3 class="m-0 text-sm font-medium text-n-slate-12">
        {{ t('ACCOUNT_SUBSCRIPTION.TOP_UP.HISTORY.TITLE') }}
      </h3>
      <ul class="m-0 flex list-none flex-col divide-y divide-n-weak p-0">
        <li
          v-for="entry in history"
          :key="entry.id"
          class="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 py-2 text-sm"
          data-test-id="top-up-history-row"
        >
          <span class="text-n-slate-12">{{ historyLabel(entry) }}</span>
          <span class="flex flex-wrap gap-x-3 text-n-slate-11">
            <span v-if="entry.reason !== 'expiry' && entry.remaining > 0">
              {{
                t('ACCOUNT_SUBSCRIPTION.TOP_UP.HISTORY.REMAINING', {
                  count: entry.remaining,
                  date: date(entry.expires_at),
                })
              }}
            </span>
            <span>{{ date(entry.created_at) }}</span>
          </span>
        </li>
      </ul>
    </div>
  </section>
</template>

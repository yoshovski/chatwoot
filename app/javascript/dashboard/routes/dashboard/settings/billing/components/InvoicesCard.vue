<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import api from 'dashboard/api/accountSubscription';
import Button from 'dashboard/components-next/button/Button.vue';

// Past invoices, newest first. Hidden until there is at least one.
const emit = defineEmits(['portal']);
const { t, locale } = useI18n();

// The backend returns at most this many; older ones live in the Stripe portal.
const LIMIT = 12;
const invoices = ref([]);
const failed = ref(false);

const load = async () => {
  failed.value = false;
  try {
    const { data } = await api.invoices();
    invoices.value = data.invoices;
  } catch {
    failed.value = true;
  }
};
onMounted(load);

const money = (cents, currency) =>
  new Intl.NumberFormat(locale.value, { style: 'currency', currency }).format(
    cents / 100
  );
const date = value =>
  new Date(value).toLocaleDateString(locale.value, {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
</script>

<template>
  <section
    v-if="invoices.length || failed"
    class="flex min-w-0 flex-col rounded-card bg-n-solid-2 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
  >
    <h2 class="mb-0 px-6 pb-2 pt-4 text-sm font-medium text-n-slate-12">
      {{ t('BILLING_PAGE.INVOICES.TITLE') }}
    </h2>
    <div
      v-if="failed"
      class="flex flex-wrap items-center justify-between gap-3 px-6 pb-4"
    >
      <p class="mb-0 text-sm text-n-slate-11">
        {{ t('BILLING_PAGE.INVOICES.ERROR') }}
      </p>
      <Button
        :label="t('BILLING_PAGE.RETRY')"
        size="sm"
        variant="ghost"
        color="slate"
        @click="load"
      />
    </div>
    <ul v-else class="m-0 list-none p-0">
      <li
        v-for="invoice in invoices"
        :key="invoice.id"
        class="flex items-center gap-3 border-t border-n-weak px-6 py-3 text-sm"
      >
        <span class="flex min-w-0 flex-1 flex-col sm:flex-row sm:gap-3">
          <span class="shrink-0 text-xs text-n-slate-11 sm:w-28 sm:text-sm">
            {{ date(invoice.created) }}
          </span>
          <span class="truncate text-n-slate-12">
            {{ invoice.description }}
          </span>
        </span>
        <a
          v-if="invoice.status === 'open' && invoice.pay_url"
          :href="invoice.pay_url"
          target="_blank"
          rel="noopener noreferrer"
          class="shrink-0 rounded-full bg-n-ruby-3 px-2 py-0.5 text-xs font-medium text-n-ruby-11 hover:underline"
        >
          {{ t('BILLING_PAGE.INVOICES.PAY') }}
        </a>
        <span class="shrink-0 tabular-nums text-n-slate-12">
          {{ money(invoice.total, invoice.currency) }}
        </span>
        <a
          v-if="invoice.pdf_url"
          :href="invoice.pdf_url"
          target="_blank"
          rel="noopener noreferrer"
          class="shrink-0 text-n-slate-11 hover:text-n-blue-11"
          :aria-label="t('BILLING_PAGE.INVOICES.PDF')"
          :title="t('BILLING_PAGE.INVOICES.PDF')"
        >
          <span class="i-lucide-download block size-4" aria-hidden="true" />
        </a>
      </li>
    </ul>
    <button
      v-if="invoices.length >= LIMIT"
      type="button"
      class="border-t border-n-weak px-6 py-3 text-start text-xs font-medium text-n-slate-11 hover:text-n-blue-11"
      @click="emit('portal')"
    >
      {{ t('BILLING_PAGE.INVOICES.ALL') }}
    </button>
  </section>
</template>

<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  icon: { type: String, required: true },
  title: { type: String, required: true },
  used: { type: Number, default: 0 },
  // null means the plan sets no limit; 0 is a real limit.
  limit: { type: Number, default: null },
  hint: { type: String, default: '' },
});

const WARNING_PERCENT = 80;
const { t, locale } = useI18n();
const number = value => new Intl.NumberFormat(locale.value).format(value);
const hasLimit = computed(() => props.limit !== null);
const percent = computed(() => {
  if (!hasLimit.value) return 0;
  if (props.limit === 0) return 100;
  return Math.min(100, Math.round((props.used / props.limit) * 100));
});
const barClass = computed(() => {
  if (percent.value >= 100) return 'bg-n-ruby-9';
  if (percent.value >= WARNING_PERCENT) return 'bg-n-amber-9';
  return 'bg-n-brand';
});
</script>

<template>
  <section
    class="flex min-w-0 flex-col gap-4 rounded-xl border border-n-weak bg-n-solid-1 p-4"
  >
    <div class="flex items-center gap-2 text-n-slate-11">
      <span :class="icon" class="size-4 shrink-0" aria-hidden="true" />
      <h3 class="m-0 truncate text-sm font-medium">{{ title }}</h3>
    </div>
    <div class="flex flex-wrap items-baseline gap-1.5 tabular-nums">
      <span class="text-2xl font-semibold tracking-tight text-n-slate-12">
        {{ number(used) }}
      </span>
      <span v-if="hasLimit" class="text-sm text-n-slate-11">
        {{ t('ACCOUNT_SUBSCRIPTION.PRODUCTS.OF', { limit: number(limit) }) }}
      </span>
    </div>
    <div
      v-if="hasLimit"
      class="h-1.5 w-full overflow-hidden rounded-full bg-n-alpha-2"
      role="progressbar"
      :aria-label="title"
      :aria-valuenow="percent"
      aria-valuemin="0"
      aria-valuemax="100"
    >
      <div
        class="h-full rounded-full transition-all duration-300"
        :class="barClass"
        :style="{ width: `${percent}%` }"
      />
    </div>
    <p class="m-0 mt-auto text-xs text-n-slate-11">
      {{ hasLimit ? hint : t('ACCOUNT_SUBSCRIPTION.PRODUCTS.NO_LIMIT') }}
    </p>
  </section>
</template>

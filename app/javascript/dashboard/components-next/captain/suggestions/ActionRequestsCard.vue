<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';
import { intentTarget } from './intents';

// "Requests your agent can't do yet": one row per intent, its count and a link to set it up.
const props = defineProps({
  requests: { type: Array, default: () => [] },
});

const route = useRoute();
const { t } = useI18n();

const LABELS = computed(() => ({
  order_status: {
    title: t('CAPTAIN.SUGGESTIONS.ACTIONS.INTENTS.ORDER_STATUS.TITLE'),
    cta: t('CAPTAIN.SUGGESTIONS.ACTIONS.INTENTS.ORDER_STATUS.CTA'),
  },
  cancel: {
    title: t('CAPTAIN.SUGGESTIONS.ACTIONS.INTENTS.CANCEL.TITLE'),
    cta: t('CAPTAIN.SUGGESTIONS.ACTIONS.INTENTS.CANCEL.CTA'),
  },
  return: {
    title: t('CAPTAIN.SUGGESTIONS.ACTIONS.INTENTS.RETURN.TITLE'),
    cta: t('CAPTAIN.SUGGESTIONS.ACTIONS.INTENTS.RETURN.CTA'),
  },
  booking: {
    title: t('CAPTAIN.SUGGESTIONS.ACTIONS.INTENTS.BOOKING.TITLE'),
    cta: t('CAPTAIN.SUGGESTIONS.ACTIONS.INTENTS.BOOKING.CTA'),
  },
  other: {
    title: t('CAPTAIN.SUGGESTIONS.ACTIONS.INTENTS.OTHER.TITLE'),
    cta: t('CAPTAIN.SUGGESTIONS.ACTIONS.INTENTS.OTHER.CTA'),
  },
}));

const rows = computed(() =>
  props.requests.map(request => {
    const labels = LABELS.value[request.intent] || LABELS.value.other;
    const hint = [
      t('CAPTAIN.SUGGESTIONS.CONVERSATIONS', {
        count: request.conversations_count,
      }),
      request.examples?.length &&
        t('CAPTAIN.SUGGESTIONS.ACTIONS.EXAMPLE', { text: request.examples[0] }),
    ]
      .filter(Boolean)
      .join(' · ');
    return {
      intent: request.intent,
      ...labels,
      hint,
      to: intentTarget(request.intent, route.params),
    };
  })
);
</script>

<template>
  <SectionCard :title="$t('CAPTAIN.SUGGESTIONS.ACTIONS.TITLE')">
    <p class="-mt-2 mb-0 text-sm text-n-slate-11">
      {{ $t('CAPTAIN.SUGGESTIONS.ACTIONS.DESCRIPTION') }}
    </p>
    <ul class="mb-0 flex list-none flex-col divide-y divide-n-weak ps-0">
      <li
        v-for="row in rows"
        :key="row.intent"
        class="flex flex-wrap items-center gap-x-4 gap-y-2 py-3 first:pt-0 last:pb-0"
      >
        <div class="flex min-w-0 flex-1 basis-60 items-start gap-3">
          <span
            class="mt-0.5 flex size-7 shrink-0 items-center justify-center rounded-lg bg-n-amber-3 text-n-amber-11"
          >
            <Icon icon="i-lucide-zap" class="size-4" />
          </span>
          <div class="flex min-w-0 flex-col gap-0.5">
            <span class="text-sm font-medium text-n-slate-12">
              {{ row.title }}
            </span>
            <span class="text-xs text-n-slate-11">{{ row.hint }}</span>
          </div>
        </div>
        <router-link
          :to="row.to"
          class="inline-flex shrink-0 items-center gap-1 rounded-lg px-3 py-1.5 text-sm font-medium text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak hover:bg-n-alpha-1"
        >
          {{ row.cta }}
          <Icon icon="i-lucide-arrow-right" class="size-3.5" />
        </router-link>
      </li>
    </ul>
  </SectionCard>
</template>

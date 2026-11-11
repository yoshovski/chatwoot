<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';
import UsageMeter from 'dashboard/components-next/kit/UsageMeter.vue';
import { aiPauseReasonText } from '../../settings/billing/aiPauseReason';

const props = defineProps({
  usage: { type: Object, default: null },
  isLoading: { type: Boolean, default: false },
  billingRoute: { type: Object, default: null },
});

const { t, locale } = useI18n();

const formatDate = seconds =>
  new Date(seconds * 1000).toLocaleDateString(locale.value, {
    day: 'numeric',
    month: 'short',
  });

const plan = computed(() => props.usage?.plan || {});
const trialEnded = computed(
  () => plan.value.trial && plan.value.trial_ends_at * 1000 <= Date.now()
);
const pauseReason = computed(() =>
  aiPauseReasonText(t, plan.value.ai_pause_reason)
);
const planBadge = computed(() => {
  if (!plan.value.trial) return '';
  if (trialEnded.value) return t('HOME.USAGE.TRIAL_ENDED');
  return t('HOME.USAGE.TRIAL_ENDS', {
    date: formatDate(plan.value.trial_ends_at),
  });
});

// null means no limit was set in Super Admin; 0 is a real limit.
const meter = (key, label, counts, hint = '') => {
  const { used = 0, limit = null } = counts || {};
  const hasLimit = limit !== null;
  return {
    key,
    label,
    used,
    limit,
    valueLabel: hasLimit
      ? t('HOME.USAGE.OF_LIMIT', { used, limit })
      : String(used),
    hint: hasLimit ? hint : t('HOME.USAGE.NO_LIMIT_SET'),
  };
};

const meters = computed(() => {
  if (!props.usage) return [];
  const { ai_conversations: ai, agents, inboxes, documents } = props.usage;
  return [
    meter(
      'ai',
      t('HOME.USAGE.AI_CONVERSATIONS'),
      ai,
      t('HOME.USAGE.RESETS', { date: formatDate(plan.value.quota_resets_at) })
    ),
    meter('agents', t('HOME.USAGE.SEATS'), agents),
    meter('inboxes', t('HOME.USAGE.INBOXES'), inboxes),
    meter('documents', t('HOME.USAGE.DOCUMENTS'), documents),
  ];
});
</script>

<template>
  <SectionCard
    :title="$t('HOME.USAGE.TITLE')"
    :link-label="billingRoute ? $t('HOME.USAGE.LINK') : ''"
    :to="billingRoute"
  >
    <div v-if="isLoading" class="flex flex-col gap-4" aria-busy="true">
      <span
        v-for="n in 4"
        :key="n"
        class="h-8 w-full animate-pulse rounded bg-n-alpha-2"
      />
    </div>
    <template v-else>
      <div
        v-if="planBadge || plan.ai_replies_paused"
        class="flex flex-wrap items-center gap-2 text-xs"
      >
        <span
          v-if="planBadge"
          class="rounded-full px-2 py-0.5 font-medium"
          :class="
            trialEnded
              ? 'bg-n-ruby-3 text-n-ruby-11'
              : 'bg-n-amber-3 text-n-amber-11'
          "
        >
          {{ planBadge }}
        </span>
        <span
          v-if="plan.ai_replies_paused"
          class="inline-flex items-center gap-1 text-n-ruby-11"
        >
          <Icon icon="i-lucide-circle-pause" class="size-3.5" />
          {{ $t('HOME.USAGE.PAUSED') }}
        </span>
        <span
          v-if="plan.ai_replies_paused && pauseReason"
          class="text-n-slate-11"
        >
          {{ pauseReason }}
        </span>
      </div>
      <div class="flex flex-col gap-4">
        <UsageMeter
          v-for="item in meters"
          :key="item.key"
          :label="item.label"
          :used="item.used"
          :limit="item.limit"
          :value-label="item.valueLabel"
          :hint="item.hint"
        />
      </div>
    </template>
  </SectionCard>
</template>

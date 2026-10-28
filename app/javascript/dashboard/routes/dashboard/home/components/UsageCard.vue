<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import HomeCard from './HomeCard.vue';
import UsageMeter from './UsageMeter.vue';

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
const planBadge = computed(() => {
  if (!plan.value.trial) return '';
  if (trialEnded.value) return t('HOME.USAGE.TRIAL_ENDED');
  return t('HOME.USAGE.TRIAL_ENDS', {
    date: formatDate(plan.value.trial_ends_at),
  });
});

const meters = computed(() => {
  if (!props.usage) return [];
  const { ai_conversations: ai, agents, inboxes, documents } = props.usage;
  return [
    {
      key: 'ai',
      label: t('HOME.USAGE.AI_CONVERSATIONS'),
      ...ai,
      hint: t('HOME.USAGE.RESETS', {
        date: formatDate(plan.value.quota_resets_at),
      }),
    },
    { key: 'agents', label: t('HOME.USAGE.SEATS'), ...agents },
    { key: 'inboxes', label: t('HOME.USAGE.INBOXES'), ...inboxes },
    { key: 'documents', label: t('HOME.USAGE.DOCUMENTS'), ...documents },
  ];
});
</script>

<template>
  <HomeCard
    :title="$t('HOME.USAGE.TITLE')"
    :link-label="billingRoute ? $t('HOME.USAGE.LINK') : ''"
    :to="billingRoute"
  >
    <div
      v-if="isLoading"
      class="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4"
      aria-busy="true"
    >
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
      </div>
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <UsageMeter
          v-for="meter in meters"
          :key="meter.key"
          :label="meter.label"
          :used="meter.used"
          :limit="meter.limit"
          :hint="meter.hint"
        />
      </div>
    </template>
  </HomeCard>
</template>

<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useIntervalFn } from '@vueuse/core';
import { endOfDay, getUnixTime, startOfDay } from 'date-fns';
import { useRoute, useRouter } from 'vue-router';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import CaptainHomeAPI from 'dashboard/api/captain/home';
import CardError from './CardError.vue';
import HomePerformance from './HomePerformance.vue';
import HomeProjectStatus from './HomeProjectStatus.vue';
import HomeQuickActions from './HomeQuickActions.vue';
import NeedsCard from './NeedsCard.vue';
import SetupReminder from './SetupReminder.vue';
import UsageCard from './UsageCard.vue';

const props = defineProps({
  period: { type: Number, required: true },
  dateRange: { type: Array, required: true },
  summary: { type: Object, default: null },
  metrics: { type: Array, required: true },
  needs: { type: Array, required: true },
  projectStatus: { type: Array, required: true },
  setupProgress: { type: Object, default: null },
  isLoading: { type: Boolean, default: false },
  hasError: { type: Boolean, default: false },
});
const emit = defineEmits(['selectDates', 'retry']);
const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { isAdmin } = useAdmin();
const { uiSettings, updateUISettings } = useUISettings();
const { shouldShow } = usePolicy();
const { run, isPending } = useAbortableRequest();
const live = ref(null);
const liveUnavailable = ref(false);

const refreshLive = async () => {
  try {
    const response = await run(signal => CaptainHomeAPI.live(signal));
    if (response) {
      live.value = response.data;
      liveUnavailable.value = false;
    }
  } catch {
    live.value = null;
    liveUnavailable.value = true;
  }
};
watch(
  () => route.params.accountId,
  () => {
    live.value = null;
    liveUnavailable.value = false;
    refreshLive();
  },
  { immediate: true }
);
useIntervalFn(() => {
  if (!isPending.value && document.visibilityState === 'visible') refreshLive();
}, 30_000);

const waitingQueue = {
  name: 'conversation_list_view',
  params: { listView: 'unassigned' },
};
const gettingStarted = { name: 'account_home_getting_started' };
const dismissedKey = 'home_setup_reminder_dismissed_accounts';
const accountId = computed(() => Number(route.params.accountId));
const dismissedAccounts = computed(() => uiSettings.value[dismissedKey] || []);
const showReminder = computed(
  () =>
    props.setupProgress && !dismissedAccounts.value.includes(accountId.value)
);
const dismissReminder = () => {
  updateUISettings({
    [dismissedKey]: [...dismissedAccounts.value, accountId.value],
  });
};
const testAgent = {
  name: 'captain_assistants_index',
  params: { navigationPath: 'captain_assistants_playground_index' },
};
const analytics = computed(() =>
  shouldShow(FEATURE_FLAGS.REPORTS, ['administrator', 'report_manage'])
    ? {
        name: 'conversation_reports',
        query: {
          from: getUnixTime(startOfDay(props.dateRange[0])),
          to: getUnixTime(endOfDay(props.dateRange[1])),
          range: 'custom',
        },
      }
    : null
);
const canSeeVisitors = computed(() =>
  shouldShow(FEATURE_FLAGS.CRM, ['administrator', 'agent', 'contact_manage'])
);
const canConfigureAI = computed(() =>
  shouldShow(FEATURE_FLAGS.CAPTAIN, ['administrator'])
);

const quickActions = computed(() => {
  const items = [];
  const open = live.value?.open_conversations;
  const visitors = live.value?.live_visitors;
  if (open > 0) {
    items.push({
      key: 'conversations',
      icon: 'i-lucide-messages-square',
      label: t('HOME.DASHBOARD.LIVE_CONVERSATIONS'),
      detail: t('HOME.DASHBOARD.OPEN_COUNT', { count: open }),
      to: { name: 'conversation_list_view', params: { listView: 'open' } },
    });
  }
  if (canConfigureAI.value && props.summary) {
    const aiOn = props.summary.setup?.agent_inbox;
    items.push({
      key: 'ai',
      icon: 'i-lucide-bot',
      label: t('HOME.DASHBOARD.AI_AGENT'),
      detail: aiOn ? t('HOME.DASHBOARD.TEST') : t('HOME.DASHBOARD.SET_UP_AI'),
      to: aiOn ? testAgent : gettingStarted,
    });
  }
  if (canSeeVisitors.value && visitors > 0) {
    items.push({
      key: 'visitors',
      icon: 'i-lucide-users-round',
      label: t('HOME.DASHBOARD.LIVE_VISITORS'),
      detail: t('HOME.DASHBOARD.ONLINE_COUNT', { count: visitors }, visitors),
      to: { name: 'contacts_dashboard_active' },
    });
  }
  return items;
});
</script>

<template>
  <section class="flex h-full w-full flex-col overflow-y-auto bg-n-background">
    <div
      class="mx-auto flex w-full max-w-[90rem] flex-col gap-4 px-4 py-4 sm:px-5 lg:px-6"
    >
      <CardError v-if="hasError && !summary" @retry="emit('retry')" />
      <div
        v-else
        class="grid items-start gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(17rem,27%)]"
      >
        <div class="grid min-w-0 gap-4">
          <SetupReminder
            v-if="showReminder"
            :progress="setupProgress"
            :to="gettingStarted"
            @skip="dismissReminder"
          />
          <HomeQuickActions
            v-if="quickActions.length || liveUnavailable"
            :items="quickActions"
            :unavailable="liveUnavailable"
          />
          <HomePerformance
            :period="period"
            :date-range="dateRange"
            :metrics="metrics"
            :days="summary?.days || []"
            :is-loading="isLoading"
            :has-error="hasError"
            :to="analytics"
            @select-dates="emit('selectDates', $event)"
            @retry="emit('retry')"
          />
          <NeedsCard
            :title="$t('HOME.V2.NEEDS.TITLE')"
            :items="needs"
            :is-loading="!summary && isLoading"
            :link-label="$t('HOME.DASHBOARD.VIEW_UNASSIGNED')"
            :to="waitingQueue"
            wrap-text
            @action="router.push($event.to)"
          />
        </div>
        <aside class="grid min-w-0 gap-4">
          <HomeProjectStatus
            v-if="summary"
            :items="projectStatus"
            :is-admin="isAdmin"
            :site="summary.site"
            :setup-route="isAdmin && !showReminder ? gettingStarted : null"
          />
          <UsageCard
            :usage="summary?.usage"
            :billing-route="isAdmin ? { name: 'billing_settings_index' } : null"
            :is-loading="!summary && isLoading"
            compact
          />
        </aside>
      </div>
    </div>
  </section>
</template>

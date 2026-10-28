<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import CaptainHomeAPI from 'dashboard/api/captain/home';
import { buildSetupProgress } from './homeSetup';

import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import HomeCard from './components/HomeCard.vue';
import SetupProgressCard from './components/SetupProgressCard.vue';
import StatTile from './components/StatTile.vue';
import StatusRow from './components/StatusRow.vue';
import UsageMeter from './components/UsageMeter.vue';

const SKIPPED_SETTING = 'home_setup_skipped';

const { t } = useI18n();
const { isAdmin } = useAdmin();
const { uiSettings, updateUISettings } = useUISettings();
const currentUser = useMapGetter('getCurrentUser');
const { run, isPending } = useAbortableRequest();

const summary = ref(null);
const hasError = ref(false);
const isLoading = computed(() => isPending.value || !summary.value);

const captainRoute = navigationPath => ({
  name: 'captain_assistants_index',
  params: { navigationPath },
});
const stepRoute = step =>
  step.navigationPath
    ? captainRoute(step.navigationPath)
    : { name: step.route };

const skippedSteps = computed(() => uiSettings.value[SKIPPED_SETTING] || []);
const setupProgress = computed(() =>
  buildSetupProgress(summary.value?.setup, skippedSteps.value)
);
const showSetup = computed(
  () => isAdmin.value && summary.value && !setupProgress.value.isComplete
);

const skipStep = key =>
  updateUISettings({ [SKIPPED_SETTING]: [...skippedSteps.value, key] });

const value = path =>
  path.split('.').reduce((obj, key) => obj?.[key], summary.value) ?? 0;

const quickActions = computed(() => [
  {
    key: 'unassigned',
    icon: 'i-lucide-inbox',
    label: t('HOME.QUICK_ACTIONS.UNASSIGNED'),
    value: value('quick_actions.unassigned_conversations'),
    to: { name: 'home' },
  },
  {
    key: 'unanswered',
    icon: 'i-lucide-circle-help',
    label: t('HOME.QUICK_ACTIONS.UNANSWERED'),
    value: value('quick_actions.unanswered_questions'),
    to: captainRoute('captain_assistants_faq_suggestions'),
  },
  {
    key: 'visitors',
    icon: 'i-lucide-radio',
    label: t('HOME.QUICK_ACTIONS.LIVE_VISITORS'),
    value: value('quick_actions.live_visitors'),
    to: { name: 'contacts_dashboard_active' },
  },
]);

const performance = computed(() => [
  {
    key: 'resolution',
    label: t('HOME.PERFORMANCE.AI_RESOLUTION'),
    value: `${value('performance.ai_resolution_rate')}%`,
  },
  {
    key: 'sales',
    label: t('HOME.PERFORMANCE.SALES_ASSISTED'),
    value: value('performance.sales_assisted'),
  },
  {
    key: 'leads',
    label: t('HOME.PERFORMANCE.LEADS'),
    value: value('performance.leads_captured'),
  },
]);

const projectStatus = computed(() => {
  const status = summary.value?.project_status || {};
  const domainState = { verified: 'done', pending: 'pending' }[status.domain];
  return [
    {
      key: 'widget',
      label: t('HOME.STATUS.WIDGET'),
      state: status.widget_installed ? 'done' : 'missing',
      stateLabel: status.widget_installed
        ? t('HOME.STATUS.INSTALLED')
        : t('HOME.STATUS.INSTALL'),
      to: { name: 'settings_inbox_list' },
    },
    {
      key: 'mailbox',
      label: t('HOME.STATUS.MAILBOX'),
      state: status.mailbox_connected ? 'done' : 'missing',
      stateLabel: status.mailbox_connected
        ? t('HOME.STATUS.CONNECTED')
        : t('HOME.STATUS.CONNECT'),
      to: { name: 'settings_inbox_new' },
    },
    {
      key: 'domain',
      label: t('HOME.STATUS.DOMAIN'),
      state: domainState || 'missing',
      stateLabel:
        {
          verified: t('HOME.STATUS.DOMAIN_VERIFIED'),
          pending: t('HOME.STATUS.DOMAIN_PENDING'),
        }[status.domain] || t('HOME.STATUS.DOMAIN_NONE'),
      to: {
        name: 'portals_index',
        params: { navigationPath: 'portals_settings_index' },
      },
    },
  ];
});

const loadSummary = async () => {
  hasError.value = false;
  try {
    const response = await run(signal => CaptainHomeAPI.get({ signal }));
    if (response) summary.value = response.data;
  } catch {
    hasError.value = true;
  }
};

onMounted(loadSummary);
</script>

<template>
  <section class="flex h-full w-full flex-col overflow-y-auto bg-n-background">
    <div
      class="mx-auto flex w-full max-w-[64rem] flex-col gap-6 px-4 py-6 sm:px-6 sm:py-8"
    >
      <header class="flex flex-col gap-1">
        <h1 class="text-xl font-medium text-n-slate-12">
          {{
            $t('HOME.TITLE', {
              name: currentUser.available_name || currentUser.name,
            })
          }}
        </h1>
        <p class="mb-0 text-sm text-n-slate-11">{{ $t('HOME.SUBTITLE') }}</p>
      </header>

      <div
        v-if="hasError"
        role="alert"
        class="flex flex-col items-center gap-3 rounded-xl bg-n-solid-2 p-8 text-center outline outline-1 -outline-offset-1 outline-n-container"
      >
        <Icon icon="i-lucide-circle-alert" class="size-5 text-n-ruby-10" />
        <p class="mb-0 text-sm text-n-slate-11">{{ $t('HOME.ERROR') }}</p>
        <Button
          :label="$t('HOME.RETRY')"
          size="sm"
          variant="faded"
          color="slate"
          @click="loadSummary"
        />
      </div>

      <div v-else class="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
        <SetupProgressCard
          v-if="showSetup"
          class="md:col-span-2"
          :progress="setupProgress"
          :step-route="stepRoute"
          @skip="skipStep"
        />

        <HomeCard
          :title="$t('HOME.QUICK_ACTIONS.TITLE')"
          :class="
            showSetup
              ? 'md:col-span-2 xl:col-span-1'
              : 'md:col-span-2 xl:col-span-3'
          "
        >
          <div
            class="grid grid-cols-1 gap-2"
            :class="
              showSetup ? 'sm:grid-cols-3 xl:grid-cols-1' : 'sm:grid-cols-3'
            "
          >
            <StatTile
              v-for="action in quickActions"
              :key="action.key"
              :icon="action.icon"
              :label="action.label"
              :value="action.value"
              :to="action.to"
              :is-loading="isLoading"
            />
          </div>
        </HomeCard>

        <HomeCard
          class="md:col-span-2"
          :title="$t('HOME.PERFORMANCE.TITLE')"
          :link-label="$t('HOME.PERFORMANCE.LINK')"
          :to="captainRoute('captain_assistants_overview_index')"
        >
          <div class="grid grid-cols-1 gap-2 sm:grid-cols-3">
            <StatTile
              v-for="metric in performance"
              :key="metric.key"
              :label="metric.label"
              :value="metric.value"
              :is-loading="isLoading"
            />
          </div>
          <p class="mb-0 text-xs text-n-slate-10">
            {{ $t('HOME.PERFORMANCE.WINDOW') }}
          </p>
        </HomeCard>

        <HomeCard :title="$t('HOME.STATUS.TITLE')">
          <div v-if="isLoading" class="flex flex-col gap-3" aria-busy="true">
            <span
              v-for="n in 3"
              :key="n"
              class="h-4 w-full animate-pulse rounded bg-n-alpha-2"
            />
          </div>
          <ul v-else class="flex flex-col divide-y divide-n-weak">
            <StatusRow
              v-for="item in projectStatus"
              :key="item.key"
              :label="item.label"
              :state="item.state"
              :state-label="item.stateLabel"
              :to="isAdmin ? item.to : null"
            />
          </ul>
        </HomeCard>

        <HomeCard
          class="md:col-span-2 xl:col-span-3"
          :title="$t('HOME.USAGE.TITLE')"
          :link-label="isAdmin ? $t('HOME.USAGE.LINK') : ''"
          :to="isAdmin ? { name: 'billing_settings_index' } : null"
        >
          <div
            v-if="isLoading"
            class="grid grid-cols-1 gap-4 sm:grid-cols-3"
            aria-busy="true"
          >
            <span
              v-for="n in 3"
              :key="n"
              class="h-8 w-full animate-pulse rounded bg-n-alpha-2"
            />
          </div>
          <div v-else class="grid grid-cols-1 gap-4 sm:grid-cols-3">
            <UsageMeter
              :label="$t('HOME.USAGE.AI_REPLIES')"
              :used="summary.usage.ai_replies.used"
              :limit="summary.usage.ai_replies.limit"
            />
            <UsageMeter
              :label="$t('HOME.USAGE.DOCUMENTS')"
              :used="summary.usage.documents.used"
              :limit="summary.usage.documents.limit"
            />
            <UsageMeter
              :label="$t('HOME.USAGE.CONVERSATIONS')"
              :used="summary.usage.conversations.used"
            />
          </div>
        </HomeCard>
      </div>
    </div>
  </section>
</template>

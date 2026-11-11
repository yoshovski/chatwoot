<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import CaptainHomeAPI from 'dashboard/api/captain/home';
import {
  buildSetupProgress,
  FINISHED_SETTING,
  SKIPPED_SETTING,
} from './homeSetup';

import Button from 'dashboard/components-next/button/Button.vue';
import EmptyState from 'dashboard/components-next/kit/EmptyState.vue';
import ListRow from 'dashboard/components-next/kit/ListRow.vue';
import MetricTile from 'dashboard/components-next/kit/MetricTile.vue';
import PageFrame from 'dashboard/components-next/kit/PageFrame.vue';
import PageHeader from 'dashboard/components-next/kit/PageHeader.vue';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';
import StatusPill from 'dashboard/components-next/kit/StatusPill.vue';
import SetupProgressCard from './components/SetupProgressCard.vue';
import UsageCard from './components/UsageCard.vue';

const STATUS_DONE = 'done';

const { t } = useI18n();
const router = useRouter();
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
  step.guided
    ? { name: 'account_home_setup', params: { step: step.key } }
    : { name: step.route };

const skippedSteps = computed(() => uiSettings.value[SKIPPED_SETTING] || []);
const finishedSteps = computed(() => uiSettings.value[FINISHED_SETTING] || []);
const setupProgress = computed(() =>
  buildSetupProgress(
    summary.value?.setup,
    skippedSteps.value,
    finishedSteps.value
  )
);
const showSetup = computed(
  () => isAdmin.value && summary.value && !setupProgress.value.isComplete
);

const skipStep = key =>
  updateUISettings({ [SKIPPED_SETTING]: [...skippedSteps.value, key] });
const unskipStep = key =>
  updateUISettings({
    [SKIPPED_SETTING]: skippedSteps.value.filter(step => step !== key),
  });

const value = path =>
  path.split('.').reduce((obj, key) => obj?.[key], summary.value) ?? 0;

const agentStatus = computed(() => {
  if (summary.value?.usage?.plan?.ai_replies_paused) {
    return { status: 'paused', label: t('HOME.V2.STATUS_PILL.PAUSED') };
  }
  return summary.value?.setup?.agent_inbox
    ? { status: 'live', label: t('HOME.V2.STATUS_PILL.LIVE') }
    : { status: 'attention', label: t('HOME.V2.STATUS_PILL.SETUP') };
});

const metrics = computed(() => [
  {
    key: 'ai_conversations',
    icon: 'i-lucide-bot',
    tone: 'blue',
    label: t('HOME.V2.METRICS.AI_CONVERSATIONS'),
    value: value('usage.ai_conversations.used'),
  },
  {
    key: 'resolved',
    icon: 'i-lucide-circle-check-big',
    tone: 'teal',
    label: t('HOME.V2.METRICS.RESOLVED'),
    value: `${value('performance.ai_resolution_rate')}%`,
  },
  {
    key: 'product_answers',
    icon: 'i-lucide-shopping-bag',
    tone: 'amber',
    label: t('HOME.V2.METRICS.PRODUCT_ANSWERS'),
    value: value('performance.sales_assisted'),
  },
  {
    key: 'leads',
    icon: 'i-lucide-user-round-plus',
    tone: 'violet',
    label: t('HOME.V2.METRICS.LEADS'),
    value: value('performance.leads_captured'),
  },
]);

const needs = computed(() => {
  const unassigned = value('quick_actions.unassigned_conversations');
  const unanswered = value('quick_actions.unanswered_questions');
  return [
    unassigned > 0 && {
      key: 'unassigned',
      tone: 'amber',
      title: t('HOME.V2.NEEDS.UNASSIGNED', { count: unassigned }, unassigned),
      hint: t('HOME.V2.NEEDS.UNASSIGNED_HINT'),
      action: t('HOME.V2.NEEDS.UNASSIGNED_ACTION'),
      to: { name: 'home' },
      primary: true,
    },
    unanswered > 0 && {
      key: 'unanswered',
      tone: 'teal',
      title: t('HOME.V2.NEEDS.UNANSWERED', { count: unanswered }, unanswered),
      hint: t('HOME.V2.NEEDS.UNANSWERED_HINT'),
      action: t('HOME.V2.NEEDS.UNANSWERED_ACTION'),
      to: captainRoute('captain_assistants_faq_suggestions'),
    },
  ].filter(Boolean);
});

const projectStatus = computed(() => {
  const project = summary.value?.project_status || {};
  const domainState = { verified: STATUS_DONE, pending: 'pending' }[
    project.domain
  ];
  return [
    {
      key: 'widget',
      label: t('HOME.STATUS.WIDGET'),
      state: project.widget_installed ? STATUS_DONE : 'missing',
      stateLabel: project.widget_installed
        ? t('HOME.STATUS.INSTALLED')
        : t('HOME.STATUS.INSTALL'),
      to: { name: 'settings_inbox_list' },
    },
    {
      key: 'mailbox',
      label: t('HOME.STATUS.MAILBOX'),
      state: project.mailbox_connected ? STATUS_DONE : 'missing',
      stateLabel: project.mailbox_connected
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
        }[project.domain] || t('HOME.STATUS.DOMAIN_NONE'),
      to: {
        name: 'portals_index',
        params: { navigationPath: 'portals_settings_index' },
      },
    },
  ].map(item => ({
    ...item,
    tone: { done: 'teal', pending: 'amber', missing: 'slate' }[item.state],
    canAct: isAdmin.value && item.state !== STATUS_DONE,
  }));
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
  <PageFrame>
    <template #header>
      <PageHeader
        band
        :title="
          $t('HOME.TITLE', {
            name: currentUser.available_name || currentUser.name,
          })
        "
        :description="$t('HOME.V2.SUBTITLE')"
      >
        <template v-if="summary" #action>
          <StatusPill
            inverted
            :status="agentStatus.status"
            :label="agentStatus.label"
          />
        </template>
      </PageHeader>
    </template>

    <SectionCard v-if="hasError">
      <EmptyState
        tone="error"
        icon="i-lucide-circle-alert"
        :title="$t('HOME.ERROR')"
      >
        <Button
          :label="$t('HOME.RETRY')"
          size="sm"
          variant="faded"
          color="slate"
          @click="loadSummary"
        />
      </EmptyState>
    </SectionCard>

    <template v-else>
      <SetupProgressCard
        v-if="showSetup"
        :progress="setupProgress"
        :step-route="stepRoute"
        @skip="skipStep"
        @unskip="unskipStep"
      />

      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <MetricTile
          v-for="metric in metrics"
          :key="metric.key"
          :label="metric.label"
          :value="metric.value"
          :icon="metric.icon"
          :tone="metric.tone"
          :is-loading="isLoading"
        />
      </div>

      <div class="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <div class="flex flex-col gap-4 lg:col-span-2">
          <SectionCard :title="$t('HOME.V2.NEEDS.TITLE')">
            <div v-if="isLoading" class="flex flex-col gap-3" aria-busy="true">
              <span
                v-for="n in 2"
                :key="n"
                class="h-10 w-full animate-pulse rounded bg-n-alpha-2"
              />
            </div>
            <ul
              v-else-if="needs.length"
              class="m-0 flex list-none flex-col divide-y divide-n-weak p-0"
            >
              <ListRow
                v-for="item in needs"
                :key="item.key"
                :title="item.title"
                :hint="item.hint"
                :tone="item.tone"
                :action-label="item.action"
                :primary="item.primary"
                @action="router.push(item.to)"
              />
            </ul>
            <EmptyState
              v-else
              tone="success"
              icon="i-lucide-circle-check-big"
              :title="$t('HOME.V2.NEEDS.EMPTY')"
            />
          </SectionCard>

          <SectionCard :title="$t('HOME.STATUS.TITLE')">
            <ul class="m-0 flex list-none flex-col divide-y divide-n-weak p-0">
              <ListRow
                v-for="item in projectStatus"
                :key="item.key"
                :title="item.label"
                :tone="item.tone"
                :meta="item.stateLabel"
                :action-label="item.canAct ? item.stateLabel : ''"
                @action="router.push(item.to)"
              />
            </ul>
          </SectionCard>
        </div>

        <UsageCard
          :usage="summary?.usage"
          :is-loading="isLoading"
          :billing-route="isAdmin ? { name: 'billing_settings_index' } : null"
        />
      </div>
    </template>
  </PageFrame>
</template>

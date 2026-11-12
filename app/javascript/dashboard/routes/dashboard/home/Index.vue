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
import {
  METRICS,
  PERIODS,
  dayLabels,
  metricChange,
  metricValue,
  needItems,
  statusPill,
} from './homeView';

import ListRow from 'dashboard/components-next/kit/ListRow.vue';
import PageFrame from 'dashboard/components-next/kit/PageFrame.vue';
import PageHeader from 'dashboard/components-next/kit/PageHeader.vue';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';
import StatusPill from 'dashboard/components-next/kit/StatusPill.vue';
import DaysCard from './components/DaysCard.vue';
import LeadsCard from './components/LeadsCard.vue';
import MetricStrip from './components/MetricStrip.vue';
import NeedsCard from './components/NeedsCard.vue';
import SetupProgressCard from './components/SetupProgressCard.vue';
import TopicsCard from './components/TopicsCard.vue';
import UsageCard from './components/UsageCard.vue';

const STATUS_DONE = 'done';
const TIMEZONE_OFFSET = -new Date().getTimezoneOffset() / 60;

const { t, locale } = useI18n();
const router = useRouter();
const { isAdmin } = useAdmin();
const { uiSettings, updateUISettings } = useUISettings();
const currentUser = useMapGetter('getCurrentUser');
const { run, isPending } = useAbortableRequest();

const period = ref(PERIODS[0]);
const summary = ref(null);
const hasError = ref(false);
const isLoading = computed(
  () => isPending.value || (!summary.value && !hasError.value)
);

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

const agentStatus = computed(() =>
  summary.value ? statusPill(summary.value.status, t) : null
);

const subtitle = computed(() =>
  summary.value?.site
    ? t('HOME.V2.SUBTITLE_SITE', {
        site: summary.value.site,
        days: period.value,
      })
    : t('HOME.V2.SUBTITLE', { days: period.value })
);

const metricLabels = computed(() => ({
  ai_conversations: t('HOME.V2.METRICS.AI_CONVERSATIONS'),
  resolved: t('HOME.V2.METRICS.RESOLVED'),
  handed: t('HOME.V2.METRICS.HANDED'),
  rating: t('HOME.V2.METRICS.RATING'),
  product_answers: t('HOME.V2.METRICS.PRODUCT_ANSWERS'),
}));

const metrics = computed(() =>
  METRICS.map(config => {
    const metric = summary.value?.metrics?.[config.key] || {
      value: null,
      previous: null,
      points: [],
    };
    const change = metricChange(config, metric, t);
    return {
      key: config.key,
      tone: config.tone,
      label: metricLabels.value[config.key],
      value: metricValue(config, metric.value),
      change: change.text,
      changeTone: change.tone,
      points: metric.points.filter(point => point !== null),
    };
  })
);

const needs = computed(() => needItems(summary.value?.needs || [], t));
const dayBars = computed(() =>
  dayLabels(summary.value?.days || [], period.value, locale.value)
);

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
    const response = await run(signal =>
      CaptainHomeAPI.get({
        signal,
        period: period.value,
        timezoneOffset: TIMEZONE_OFFSET,
      })
    );
    if (response) summary.value = response.data;
  } catch {
    hasError.value = true;
  }
};

const selectPeriod = option => {
  if (option === period.value) return;
  period.value = option;
  loadSummary();
};

const openConversation = lead =>
  router.push({
    name: 'inbox_conversation',
    params: { conversation_id: lead.id },
  });

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
        :description="subtitle"
      >
        <template #action>
          <div
            role="group"
            :aria-label="$t('HOME.V2.PERIOD.LABEL')"
            class="flex rounded-full bg-white/15 p-0.5"
          >
            <button
              v-for="days in PERIODS"
              :key="days"
              type="button"
              class="rounded-full px-3 py-1 text-xs font-medium"
              :class="
                days === period
                  ? 'bg-white/25 text-white'
                  : 'text-white/80 hover:bg-white/10'
              "
              :aria-pressed="days === period"
              @click="selectPeriod(days)"
            >
              {{ $t('HOME.V2.PERIOD.DAYS', { days }) }}
            </button>
          </div>
          <StatusPill
            v-if="agentStatus"
            inverted
            :status="agentStatus.status"
            :label="agentStatus.label"
          />
        </template>
      </PageHeader>
    </template>

    <SetupProgressCard
      v-if="showSetup"
      :progress="setupProgress"
      :step-route="stepRoute"
      @skip="skipStep"
      @unskip="unskipStep"
    />

    <MetricStrip
      :metrics="metrics"
      :period="period"
      :is-loading="isLoading"
      :has-error="hasError"
      @retry="loadSummary"
    />

    <div class="grid grid-cols-1 gap-4 lg:grid-cols-3">
      <div class="flex min-w-0 flex-col gap-4 lg:col-span-2">
        <NeedsCard
          :items="needs"
          :is-loading="isLoading"
          :has-error="hasError"
          @action="item => router.push(item.to)"
          @retry="loadSummary"
        />
        <LeadsCard
          :leads="summary?.leads || []"
          :is-loading="isLoading"
          :has-error="hasError"
          @open="openConversation"
          @retry="loadSummary"
        />
        <SectionCard v-if="summary" :title="$t('HOME.STATUS.TITLE')">
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
      <div class="flex min-w-0 flex-col gap-4">
        <UsageCard
          :usage="summary?.usage"
          :is-loading="isLoading"
          :has-error="hasError"
          :billing-route="isAdmin ? { name: 'billing_settings_index' } : null"
          @retry="loadSummary"
        />
        <DaysCard
          :days="dayBars"
          :is-loading="isLoading"
          :has-error="hasError"
          @retry="loadSummary"
        />
        <TopicsCard
          :topics="summary?.topics || []"
          :is-loading="isLoading"
          :has-error="hasError"
          @retry="loadSummary"
        />
      </div>
    </div>
  </PageFrame>
</template>

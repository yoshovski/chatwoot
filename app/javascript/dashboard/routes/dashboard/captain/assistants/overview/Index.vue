<script setup>
import { computed, onUnmounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { RouterLink, useRoute, useRouter } from 'vue-router';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import {
  isAbortError,
  useAbortableRequest,
} from 'dashboard/composables/useAbortableRequest';
import CaptainAssistant from 'dashboard/api/captain/assistant';
import CaptainAssistantStats from 'dashboard/api/captain/assistantStats';

import Button from 'dashboard/components-next/button/Button.vue';
import SidePanel from 'dashboard/components-next/side-panel/SidePanel.vue';
import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import TestAgentButton from 'dashboard/components-next/captain/TestAgentButton.vue';
import CaptainPaywall from 'dashboard/components-next/captain/pageComponents/Paywall.vue';
import RangeSelector from 'dashboard/components-next/captain/pageComponents/overview/RangeSelector.vue';
import MetricCard from 'dashboard/components-next/captain/pageComponents/overview/MetricCard.vue';
import AssistantDrilldownDrawer from 'dashboard/components-next/captain/pageComponents/overview/AssistantDrilldownDrawer.vue';
import KnowledgeCard from 'dashboard/components-next/captain/pageComponents/overview/KnowledgeCard.vue';
import ResolutionFlowCard from 'dashboard/components-next/captain/pageComponents/overview/v2/ResolutionFlowCard.vue';
import ResolutionTrendCard from 'dashboard/components-next/captain/pageComponents/overview/v2/ResolutionTrendCard.vue';
import CsatCard from 'dashboard/components-next/captain/pageComponents/overview/v2/CsatCard.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const { checkPermissions } = usePolicy();
const canDrilldown = computed(() => checkPermissions(['administrator']));

const selectedRange = ref('7');

const accountId = computed(() => route.params.accountId);
const assistantId = computed(() => Number(route.params.assistantId));
const assistant = computed(() =>
  store.getters['captainAssistants/getRecord'](assistantId.value)
);
const assistantConfig = computed(() => assistant.value?.config || {});

const inboxes = useMapGetter('captainInboxes/getRecords');
const inboxesUIFlags = useMapGetter('captainInboxes/getUIFlags');

const metricStats = ref(null);
const faqStats = ref(null);
const isFetchingMetrics = ref(false);
const isFetchingFaqStats = ref(false);

const reportPanel = ref(null);
const isReportOpen = ref(false);
const reportOverview = ref(null);
const resolutionFlow = ref(null);
const resolutionTrend = ref(null);

const { run: runReportRequest, isPending: isFetchingReport } =
  useAbortableRequest();

let metricsFetchToken = 0;
let faqStatsFetchToken = 0;
let metricsAbortController = null;
let faqStatsAbortController = null;

const fetchMetrics = async () => {
  metricsFetchToken += 1;
  const token = metricsFetchToken;
  metricsAbortController?.abort();
  metricsAbortController = new AbortController();
  const { signal } = metricsAbortController;
  metricStats.value = null;
  isFetchingMetrics.value = true;

  const requestMetrics = () =>
    CaptainAssistant.getMetrics({
      assistantId: assistantId.value,
      range: selectedRange.value,
      signal,
    });

  let data = null;
  try {
    ({ data } = await requestMetrics());
  } catch {
    try {
      if (token === metricsFetchToken && !signal.aborted)
        ({ data } = await requestMetrics());
    } catch {
      data = null;
    }
  }

  if (token !== metricsFetchToken || signal.aborted) return;
  metricStats.value = data;
  isFetchingMetrics.value = false;
};

const fetchFaqStats = async () => {
  faqStatsFetchToken += 1;
  const token = faqStatsFetchToken;
  faqStatsAbortController?.abort();
  faqStatsAbortController = new AbortController();
  const { signal } = faqStatsAbortController;
  faqStats.value = null;
  isFetchingFaqStats.value = true;

  try {
    const { data } = await CaptainAssistant.getFaqStats({
      assistantId: assistantId.value,
      signal,
    });
    if (token === faqStatsFetchToken && !signal.aborted) faqStats.value = data;
  } catch {
    if (token === faqStatsFetchToken && !signal.aborted) faqStats.value = null;
  } finally {
    if (token === faqStatsFetchToken && !signal.aborted) {
      isFetchingFaqStats.value = false;
    }
  }
};

const optionalResponseData = async request => {
  try {
    return (await request).data;
  } catch (error) {
    if (isAbortError(error)) throw error;
    return null;
  }
};

const fetchReportCharts = async () => {
  if (!isReportOpen.value) return;
  const results = await runReportRequest(signal => {
    const request = {
      assistantId: assistantId.value,
      range: selectedRange.value,
      signal,
    };

    return Promise.all([
      optionalResponseData(CaptainAssistantStats.getOverview(request)),
      optionalResponseData(CaptainAssistantStats.getResolutionFlow(request)),
      optionalResponseData(CaptainAssistantStats.getResolutionTrend(request)),
    ]);
  });

  if (results) {
    [reportOverview.value, resolutionFlow.value, resolutionTrend.value] =
      results;
  }
};

onUnmounted(() => {
  metricsAbortController?.abort();
  faqStatsAbortController?.abort();
});

watch(
  [selectedRange, assistantId],
  () => {
    fetchMetrics();
    fetchReportCharts();
  },
  { immediate: true }
);

watch(
  assistantId,
  id => {
    if (!id) return;
    fetchFaqStats();
    store.dispatch('captainInboxes/get', { assistantId: id });
    if (!assistant.value) {
      store.dispatch('captainAssistants/show', id);
    }
  },
  { immediate: true }
);

const routeTo = (name, query = undefined) => ({
  name,
  params: {
    accountId: accountId.value,
    assistantId: assistantId.value,
  },
  ...(query ? { query } : {}),
});

const handoffDoneSummary = computed(() => {
  const mode = assistantConfig.value.handoff_when_online;
  if (mode === 'email_followup') {
    return t('CAPTAIN.OVERVIEW.READINESS.STEPS.HANDOFF.DONE_EMAIL');
  }
  if (mode === 'never') {
    return t('CAPTAIN.OVERVIEW.READINESS.STEPS.HANDOFF.DONE_NEVER');
  }
  return t('CAPTAIN.OVERVIEW.READINESS.STEPS.HANDOFF.DONE_TRANSFER');
});

const knowledgeDoneSummary = computed(() => {
  const docs = faqStats.value?.documents || 0;
  const faqs = faqStats.value?.faqs || 0;
  const sourcesText = t(
    'CAPTAIN.OVERVIEW.READINESS.STEPS.KNOWLEDGE.SOURCES_COUNT',
    { count: docs },
    docs
  );
  const faqsText = t(
    'CAPTAIN.OVERVIEW.READINESS.STEPS.KNOWLEDGE.FAQS_COUNT',
    { count: faqs },
    faqs
  );
  if (docs > 0 && faqs > 0) {
    return t('CAPTAIN.OVERVIEW.READINESS.STEPS.KNOWLEDGE.DONE_BOTH', {
      sources: sourcesText,
      faqs: faqsText,
    });
  }
  return docs > 0 ? sourcesText : faqsText;
});

const readinessSteps = computed(() => {
  const docs = faqStats.value?.documents || 0;
  const approved = faqStats.value?.approved || 0;
  const knowledgeReady = docs > 0 || approved > 0;

  const handoffSet = Boolean(
    assistantConfig.value.handoff_when_online ||
      assistantConfig.value.handoff_fallback_team_id ||
      assistantConfig.value.handoff_fallback_agent_id ||
      assistantConfig.value.handoff_rules?.length
  );

  const tested = Boolean(faqStats.value?.tested);
  const channelLive = inboxes.value.length > 0;
  const firstChannelName = inboxes.value[0]?.name || '';

  return [
    {
      key: 'knowledge',
      done: knowledgeReady,
      title: t('CAPTAIN.OVERVIEW.READINESS.STEPS.KNOWLEDGE.TITLE'),
      summary: knowledgeReady
        ? knowledgeDoneSummary.value
        : t('CAPTAIN.OVERVIEW.READINESS.STEPS.KNOWLEDGE.TODO'),
      actionLabel: t('CAPTAIN.OVERVIEW.READINESS.STEPS.KNOWLEDGE.ACTION'),
      editLabel: t('CAPTAIN.OVERVIEW.READINESS.STEPS.KNOWLEDGE.EDIT'),
      to: routeTo('captain_assistants_documents_index'),
    },
    {
      key: 'handoff',
      done: handoffSet,
      title: t('CAPTAIN.OVERVIEW.READINESS.STEPS.HANDOFF.TITLE'),
      summary: handoffSet
        ? handoffDoneSummary.value
        : t('CAPTAIN.OVERVIEW.READINESS.STEPS.HANDOFF.TODO'),
      actionLabel: t('CAPTAIN.OVERVIEW.READINESS.STEPS.HANDOFF.ACTION'),
      editLabel: t('CAPTAIN.OVERVIEW.READINESS.STEPS.HANDOFF.EDIT'),
      to: routeTo('captain_assistants_settings_system_index'),
    },
    {
      key: 'tested',
      done: tested,
      title: t('CAPTAIN.OVERVIEW.READINESS.STEPS.TESTED.TITLE'),
      summary: tested
        ? t('CAPTAIN.OVERVIEW.READINESS.STEPS.TESTED.DONE')
        : t('CAPTAIN.OVERVIEW.READINESS.STEPS.TESTED.TODO'),
      actionLabel: t('CAPTAIN.OVERVIEW.READINESS.STEPS.TESTED.ACTION'),
      editLabel: t('CAPTAIN.OVERVIEW.READINESS.STEPS.TESTED.EDIT'),
      to: routeTo('captain_assistants_playground_index'),
    },
    {
      key: 'channel',
      done: channelLive,
      title: t('CAPTAIN.OVERVIEW.READINESS.STEPS.CHANNEL.TITLE'),
      summary: channelLive
        ? t('CAPTAIN.OVERVIEW.READINESS.STEPS.CHANNEL.DONE', {
            channel: firstChannelName,
          })
        : t('CAPTAIN.OVERVIEW.READINESS.STEPS.CHANNEL.TODO'),
      actionLabel: t('CAPTAIN.OVERVIEW.READINESS.STEPS.CHANNEL.ACTION'),
      editLabel: t('CAPTAIN.OVERVIEW.READINESS.STEPS.CHANNEL.EDIT'),
      to: routeTo('captain_assistants_inboxes_index'),
    },
  ];
});

const completedStepsCount = computed(
  () => readinessSteps.value.filter(step => step.done).length
);
const nextUnfinishedStep = computed(() =>
  readinessSteps.value.find(step => !step.done)
);
const allStepsComplete = computed(
  () => completedStepsCount.value === readinessSteps.value.length
);
const hasHandledConversations = computed(
  () => (metricStats.value?.conversations_handled?.current || 0) > 0
);
const isInitialLoading = computed(
  () => isFetchingFaqStats.value || Boolean(inboxesUIFlags.value?.fetchingList)
);
const showReadinessChecklist = computed(
  () => !isInitialLoading.value && !allStepsComplete.value
);
const isRunningAgent = computed(
  () =>
    allStepsComplete.value ||
    inboxes.value.length > 0 ||
    hasHandledConversations.value
);

const channelStatusLabel = computed(() => {
  const count = inboxes.value.length;
  if (count === 0) return t('CAPTAIN.OVERVIEW.STATUS_LINE.NOT_LIVE');
  const first = inboxes.value[0]?.name || '';
  if (count === 1) {
    return t('CAPTAIN.OVERVIEW.STATUS_LINE.LIVE_SINGLE', { channel: first });
  }
  return t('CAPTAIN.OVERVIEW.STATUS_LINE.LIVE_MULTIPLE', {
    channel: first,
    extra: count - 1,
  });
});

const audienceStatusLabel = computed(() => {
  const conditions = assistantConfig.value.audience?.conditions;
  if (Array.isArray(conditions) && conditions.length > 0) {
    return t('CAPTAIN.OVERVIEW.STATUS_LINE.AUDIENCE_FILTERED');
  }
  return t('CAPTAIN.OVERVIEW.STATUS_LINE.AUDIENCE_ALL');
});

const scheduleStatusLabel = computed(() => {
  const window = assistantConfig.value.response_window;
  if (window === 'business_hours') {
    return t('CAPTAIN.OVERVIEW.STATUS_LINE.SCHEDULE_BUSINESS_HOURS');
  }
  if (window === 'outside_business_hours') {
    return t('CAPTAIN.OVERVIEW.STATUS_LINE.SCHEDULE_OUTSIDE_HOURS');
  }
  return t('CAPTAIN.OVERVIEW.STATUS_LINE.SCHEDULE_ALWAYS');
});

const resolveTrendGood = (trendValue, direction) => {
  if (direction === 'neutral' || trendValue === 0) return null;
  return direction === 'up' ? trendValue > 0 : trendValue < 0;
};

const TREND_SUFFIX = { percent: '%', point: ' pts', absolute: '' };

const formatDuration = hours =>
  hours >= 100 ? `${Math.round(hours / 24)}d` : `${hours}h`;

const metricFor = (statKey, formatValue, direction, trendKind = 'percent') => {
  const data = metricStats.value?.[statKey];
  if (!data) return { value: '—', trend: '', trendGood: null };

  const sign = data.trend > 0 ? '+' : '';
  return {
    value: formatValue(data.current),
    trend: `${sign}${data.trend}${TREND_SUFFIX[trendKind]}`,
    trendGood: resolveTrendGood(data.trend, direction),
  };
};

const primaryMetrics = computed(() => [
  {
    key: 'handled',
    metric: 'conversations_handled',
    label: t('CAPTAIN.OVERVIEW.METRICS.HANDLED.LABEL'),
    hint: t('CAPTAIN.OVERVIEW.METRICS.HANDLED.HINT'),
    ...metricFor('conversations_handled', v => v.toLocaleString(), 'up'),
  },
  {
    key: 'autoResolution',
    metric: 'auto_resolution_rate',
    label: t('CAPTAIN.OVERVIEW.METRICS.AUTO_RESOLUTION.LABEL'),
    hint: t('CAPTAIN.OVERVIEW.METRICS.AUTO_RESOLUTION.HINT'),
    ...metricFor('auto_resolution_rate', v => `${v}%`, 'up', 'point'),
  },
  {
    key: 'hoursSaved',
    label: t('CAPTAIN.OVERVIEW.METRICS.HOURS_SAVED.LABEL'),
    hint: t('CAPTAIN.OVERVIEW.METRICS.HOURS_SAVED.HINT'),
    ...metricFor('hours_saved', formatDuration, 'up'),
  },
]);

const reportMetrics = computed(() => [
  {
    key: 'handoff',
    metric: 'handoff_rate',
    label: t('CAPTAIN.OVERVIEW.METRICS.HANDOFF.LABEL'),
    hint: t('CAPTAIN.OVERVIEW.METRICS.HANDOFF.HINT'),
    ...metricFor('handoff_rate', v => `${v}%`, 'down', 'point'),
  },
  {
    key: 'reopen',
    metric: 'reopen_rate',
    label: t('CAPTAIN.OVERVIEW.METRICS.REOPEN.LABEL'),
    hint: t('CAPTAIN.OVERVIEW.METRICS.REOPEN.HINT'),
    ...metricFor('reopen_rate', v => `${v}%`, 'down', 'point'),
  },
  {
    key: 'depth',
    label: t('CAPTAIN.OVERVIEW.METRICS.DEPTH.LABEL'),
    hint: t('CAPTAIN.OVERVIEW.METRICS.DEPTH.HINT'),
    ...metricFor(
      'conversation_depth',
      v => v.toFixed(1),
      'neutral',
      'absolute'
    ),
  },
]);

const attentionItems = computed(() => {
  const stats = faqStats.value;
  if (!stats) return [];

  const items = [];
  if (stats.failed_sources > 0) {
    items.push({
      key: 'failedSources',
      icon: 'i-lucide-circle-alert text-n-ruby-11',
      title: t(
        'CAPTAIN.OVERVIEW.NEEDS_ATTENTION.FAILED_SOURCES.TITLE',
        { count: stats.failed_sources },
        stats.failed_sources
      ),
      description: t(
        'CAPTAIN.OVERVIEW.NEEDS_ATTENTION.FAILED_SOURCES.DESCRIPTION'
      ),
      actionLabel: t('CAPTAIN.OVERVIEW.NEEDS_ATTENTION.FAILED_SOURCES.ACTION'),
      to: routeTo('captain_assistants_documents_index', { filter: 'failed' }),
    });
  }

  if (stats.unanswered_questions > 0) {
    items.push({
      key: 'unansweredQuestions',
      icon: 'i-lucide-circle-help text-n-amber-11',
      title: t(
        'CAPTAIN.OVERVIEW.NEEDS_ATTENTION.UNANSWERED_QUESTIONS.TITLE',
        { count: stats.unanswered_questions },
        stats.unanswered_questions
      ),
      description: t(
        'CAPTAIN.OVERVIEW.NEEDS_ATTENTION.UNANSWERED_QUESTIONS.DESCRIPTION'
      ),
      actionLabel: t(
        'CAPTAIN.OVERVIEW.NEEDS_ATTENTION.UNANSWERED_QUESTIONS.ACTION'
      ),
      to: routeTo('captain_assistants_faq_suggestions'),
    });
  }

  if (stats.paused_actions > 0) {
    items.push({
      key: 'pausedActions',
      icon: 'i-lucide-circle-pause text-n-amber-11',
      title: t(
        'CAPTAIN.OVERVIEW.NEEDS_ATTENTION.PAUSED_ACTIONS.TITLE',
        { count: stats.paused_actions },
        stats.paused_actions
      ),
      description: t(
        'CAPTAIN.OVERVIEW.NEEDS_ATTENTION.PAUSED_ACTIONS.DESCRIPTION'
      ),
      actionLabel: t('CAPTAIN.OVERVIEW.NEEDS_ATTENTION.PAUSED_ACTIONS.ACTION'),
      to: routeTo('captain_tools_index'),
    });
  }

  return items;
});

const openReportPanel = () => {
  isReportOpen.value = true;
  reportPanel.value?.open();
  fetchReportCharts();
};

const closeReportPanel = () => {
  isReportOpen.value = false;
  reportPanel.value?.close();
};

const drilldown = ref({ metric: '', label: '', value: '' });
const isDrilldownOpen = ref(false);

const openDrilldown = metric => {
  if (isReportOpen.value) closeReportPanel();
  drilldown.value = {
    metric: metric.metric,
    label: metric.label,
    value: metric.value,
  };
  isDrilldownOpen.value = true;
};

const closeDrilldown = () => {
  isDrilldownOpen.value = false;
};
</script>

<template>
  <PageLayout
    :header-title="$t('CAPTAIN.OVERVIEW.HEADER')"
    :is-empty="false"
    :show-pagination-footer="false"
    :show-know-more="false"
    :feature-flag="FEATURE_FLAGS.CAPTAIN"
  >
    <template #headerActions>
      <div v-if="isRunningAgent" class="flex flex-wrap items-center gap-2">
        <RangeSelector v-model="selectedRange" />
        <Button
          type="button"
          variant="faded"
          color="slate"
          size="sm"
          icon="i-lucide-chart-bar"
          :label="$t('CAPTAIN.OVERVIEW.VIEW_REPORT')"
          @click="openReportPanel"
        />
        <TestAgentButton :assistant-id="assistantId" />
      </div>
    </template>
    <template #paywall>
      <CaptainPaywall />
    </template>
    <template #body>
      <div class="flex flex-col gap-6 pb-20">
        <!-- Readiness checklist for a new / incomplete AI agent -->
        <section
          v-if="showReadinessChecklist"
          class="overflow-hidden border rounded-xl bg-n-solid-1 border-n-weak"
        >
          <div
            class="flex flex-wrap items-center justify-between gap-4 px-5 py-4 border-b border-n-weak"
          >
            <div class="min-w-0">
              <div class="flex items-center gap-2.5">
                <h2 class="m-0 text-base font-medium text-n-slate-12">
                  {{ $t('CAPTAIN.OVERVIEW.READINESS.TITLE') }}
                </h2>
                <span
                  class="px-2 py-0.5 text-xs font-medium rounded-full bg-n-alpha-2 text-n-slate-11 tabular-nums"
                >
                  {{
                    $t('CAPTAIN.OVERVIEW.READINESS.PROGRESS', {
                      completed: completedStepsCount,
                      total: readinessSteps.length,
                    })
                  }}
                </span>
              </div>
              <p class="mt-0.5 mb-0 text-sm text-n-slate-11">
                {{ $t('CAPTAIN.OVERVIEW.READINESS.DESCRIPTION') }}
              </p>
            </div>
          </div>

          <div class="divide-y divide-n-weak">
            <div
              v-for="(step, idx) in readinessSteps"
              :key="step.key"
              class="flex flex-wrap items-center justify-between gap-4 px-5 py-3.5"
            >
              <div class="flex items-start gap-3 min-w-0">
                <span
                  v-if="step.done"
                  class="mt-0.5 shrink-0 size-5 i-lucide-check-circle-2 text-n-teal-11"
                />
                <span
                  v-else
                  class="mt-0.5 grid shrink-0 size-5 place-content-center rounded-full border text-xs font-medium tabular-nums"
                  :class="
                    nextUnfinishedStep?.key === step.key
                      ? 'border-n-brand bg-n-brand/10 text-n-brand'
                      : 'border-n-strong text-n-slate-11'
                  "
                >
                  {{ idx + 1 }}
                </span>
                <div class="min-w-0">
                  <div class="text-sm font-medium text-n-slate-12">
                    {{ step.title }}
                  </div>
                  <div class="text-sm text-n-slate-11">
                    {{ step.summary }}
                  </div>
                </div>
              </div>
              <Button
                v-if="nextUnfinishedStep?.key === step.key"
                type="button"
                size="sm"
                icon="i-lucide-arrow-right"
                trailing-icon
                :label="step.actionLabel"
                @click="router.push(step.to)"
              />
              <RouterLink
                v-else
                :to="step.to"
                class="text-sm font-medium shrink-0 text-n-slate-11 hover:text-n-slate-12"
              >
                {{ step.done ? step.editLabel : step.actionLabel }}
              </RouterLink>
            </div>
          </div>
        </section>

        <!-- Running AI agent view -->
        <template v-if="isRunningAgent">
          <!-- One status line with edit links -->
          <div
            class="flex flex-wrap items-center justify-between gap-3 px-4 py-3 border rounded-xl bg-n-solid-1 border-n-weak"
          >
            <div
              class="flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-n-slate-12"
            >
              <span
                class="shrink-0 size-2 rounded-full"
                :class="inboxes.length > 0 ? 'bg-n-teal-9' : 'bg-n-amber-9'"
              />
              <RouterLink
                :to="routeTo('captain_assistants_inboxes_index')"
                class="font-medium text-n-slate-12 hover:text-n-brand hover:underline"
              >
                {{ channelStatusLabel }}
              </RouterLink>
              <span
                aria-hidden="true"
                class="size-1 rounded-full bg-n-slate-8"
              />
              <RouterLink
                :to="routeTo('captain_assistants_settings_audience_index')"
                class="text-n-slate-11 hover:text-n-brand hover:underline"
              >
                {{ audienceStatusLabel }}
              </RouterLink>
              <span
                aria-hidden="true"
                class="size-1 rounded-full bg-n-slate-8"
              />
              <RouterLink
                :to="routeTo('captain_assistants_settings_schedule_index')"
                class="text-n-slate-11 hover:text-n-brand hover:underline"
              >
                {{ scheduleStatusLabel }}
              </RouterLink>
            </div>

            <RouterLink
              :to="routeTo('captain_assistants_inboxes_index')"
              class="text-xs font-medium shrink-0 text-n-brand hover:underline"
            >
              {{ $t('CAPTAIN.OVERVIEW.STATUS_LINE.EDIT_CHANNELS') }}
            </RouterLink>
          </div>

          <!-- Three key numbers -->
          <div
            class="grid grid-cols-1 gap-px overflow-hidden border rounded-xl sm:grid-cols-3 bg-n-weak border-n-weak"
          >
            <MetricCard
              v-for="metric in primaryMetrics"
              :key="metric.key"
              :label="metric.label"
              :value="metric.value"
              :trend="metric.trend"
              :hint="metric.hint"
              :trend-good="metric.trendGood"
              :loading="isFetchingMetrics"
              :clickable="
                canDrilldown && Boolean(metric.metric) && !isFetchingMetrics
              "
              @click="openDrilldown(metric)"
            />
          </div>

          <!-- Short Needs attention list -->
          <section
            class="overflow-hidden border rounded-xl bg-n-solid-1 border-n-weak"
          >
            <div class="px-5 py-3.5 border-b border-n-weak">
              <h2 class="m-0 text-sm font-medium text-n-slate-12">
                {{ $t('CAPTAIN.OVERVIEW.NEEDS_ATTENTION.TITLE') }}
              </h2>
            </div>

            <div
              v-if="attentionItems.length === 0"
              class="flex items-center gap-2.5 px-5 py-4 text-sm text-n-slate-11"
            >
              <span
                class="shrink-0 size-4 i-lucide-check-circle-2 text-n-teal-11"
              />
              <span>{{
                $t('CAPTAIN.OVERVIEW.NEEDS_ATTENTION.ALL_CLEAR')
              }}</span>
            </div>

            <div v-else class="divide-y divide-n-weak">
              <div
                v-for="item in attentionItems"
                :key="item.key"
                class="flex flex-wrap items-center justify-between gap-4 px-5 py-3.5"
              >
                <div class="flex items-start gap-3 min-w-0">
                  <span class="mt-0.5 shrink-0 size-4" :class="item.icon" />
                  <div class="min-w-0">
                    <div class="text-sm font-medium text-n-slate-12">
                      {{ item.title }}
                    </div>
                    <div class="text-sm text-n-slate-11">
                      {{ item.description }}
                    </div>
                  </div>
                </div>
                <Button
                  type="button"
                  variant="faded"
                  color="slate"
                  size="sm"
                  :label="item.actionLabel"
                  @click="router.push(item.to)"
                />
              </div>
            </div>
          </section>
        </template>
      </div>

      <!-- Deeper charts & metrics behind "View report" side panel -->
      <SidePanel
        ref="reportPanel"
        :title="$t('CAPTAIN.OVERVIEW.REPORT_PANEL.TITLE')"
        :description="$t('CAPTAIN.OVERVIEW.REPORT_PANEL.DESCRIPTION')"
        width="5xl"
        @close="isReportOpen = false"
      >
        <div class="flex flex-col gap-5">
          <div>
            <h4
              class="mt-0 mb-2.5 text-xs font-medium uppercase tracking-wider text-n-slate-11"
            >
              {{ $t('CAPTAIN.OVERVIEW.REPORT_PANEL.OUTCOMES_TITLE') }}
            </h4>
            <div
              class="grid grid-cols-1 gap-px overflow-hidden border rounded-xl sm:grid-cols-3 bg-n-weak border-n-weak"
            >
              <MetricCard
                v-for="metric in reportMetrics"
                :key="metric.key"
                :label="metric.label"
                :value="metric.value"
                :trend="metric.trend"
                :hint="metric.hint"
                :trend-good="metric.trendGood"
                :loading="isFetchingMetrics"
                :clickable="
                  canDrilldown && Boolean(metric.metric) && !isFetchingMetrics
                "
                @click="openDrilldown(metric)"
              />
            </div>
          </div>

          <KnowledgeCard :knowledge="faqStats ?? undefined" />

          <ResolutionFlowCard
            :flow="resolutionFlow"
            :loading="isFetchingReport"
          />

          <ResolutionTrendCard
            :trend="resolutionTrend"
            :loading="isFetchingReport"
          />

          <CsatCard
            :autonomous="reportOverview?.autonomous_csat_score"
            :assisted="reportOverview?.assisted_csat_score"
            :human-only="reportOverview?.human_only_csat_score"
            :loading="isFetchingReport"
          />
        </div>
      </SidePanel>

      <AssistantDrilldownDrawer
        v-if="canDrilldown"
        :open="isDrilldownOpen"
        :assistant-id="assistantId"
        :metric="drilldown.metric"
        :metric-name="drilldown.label"
        :metric-value="drilldown.value"
        :range="selectedRange"
        @close="closeDrilldown"
      />
    </template>
  </PageLayout>
</template>

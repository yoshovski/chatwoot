<script setup>
import { computed, onUnmounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { RouterLink, useRoute, useRouter } from 'vue-router';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import CaptainAssistant from 'dashboard/api/captain/assistant';
import {
  STEP_STATES,
  attentionCounts,
  readinessStates,
  readinessSummary,
} from './overviewReadiness';

import Button from 'dashboard/components-next/button/Button.vue';
import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import TestAgentButton from 'dashboard/components-next/captain/TestAgentButton.vue';
import CaptainPaywall from 'dashboard/components-next/captain/pageComponents/Paywall.vue';
import MetricTile from 'dashboard/components-next/kit/MetricTile.vue';
import RangeSelector from 'dashboard/components-next/captain/pageComponents/overview/RangeSelector.vue';
import AssistantDrilldownDrawer from 'dashboard/components-next/captain/pageComponents/overview/AssistantDrilldownDrawer.vue';

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

const metricStats = ref(null);
const faqStats = ref(null);
const isFetchingMetrics = ref(false);
const faqStatsFailed = ref(false);
// loading | loaded | failed: a failed channel list is unknown, not "not live".
const channelsStatus = ref('loading');

let metricsFetchToken = 0;
let metricsAbortController = null;
const { run: runFaqStats, isPending: isFetchingFaqStats } =
  useAbortableRequest();

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
  faqStats.value = null;
  faqStatsFailed.value = false;
  try {
    const response = await runFaqStats(signal =>
      CaptainAssistant.getFaqStats({ assistantId: assistantId.value, signal })
    );
    if (response) faqStats.value = response.data;
  } catch {
    faqStatsFailed.value = true;
  }
};

const fetchChannels = async () => {
  channelsStatus.value = 'loading';
  try {
    await store.dispatch('captainInboxes/get', {
      assistantId: assistantId.value,
    });
    channelsStatus.value = 'loaded';
  } catch {
    channelsStatus.value = 'failed';
  }
};

const retryStatus = () => {
  if (faqStatsFailed.value) fetchFaqStats();
  if (channelsStatus.value === 'failed') fetchChannels();
};

onUnmounted(() => {
  metricsAbortController?.abort();
});

watch(
  [selectedRange, assistantId],
  () => {
    fetchMetrics();
  },
  { immediate: true }
);

watch(
  assistantId,
  id => {
    if (!id) return;
    fetchFaqStats();
    fetchChannels();
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

const stepStates = computed(() =>
  readinessStates({
    faqStats: faqStats.value,
    config: assistantConfig.value,
    channelCount: inboxes.value.length,
    channelsKnown: channelsStatus.value === 'loaded',
  })
);
const readiness = computed(() => readinessSummary(stepStates.value));

const stepSummary = (key, doneSummary, todoSummary) =>
  ({
    [STEP_STATES.DONE]: doneSummary,
    [STEP_STATES.TODO]: todoSummary,
    [STEP_STATES.UNKNOWN]: t('CAPTAIN.OVERVIEW.READINESS.UNKNOWN'),
  })[stepStates.value[key]];

const readinessSteps = computed(() => {
  const firstChannelName = inboxes.value[0]?.name || '';

  return [
    {
      key: 'knowledge',
      title: t('CAPTAIN.OVERVIEW.READINESS.STEPS.KNOWLEDGE.TITLE'),
      summary: stepSummary(
        'knowledge',
        knowledgeDoneSummary.value,
        t('CAPTAIN.OVERVIEW.READINESS.STEPS.KNOWLEDGE.TODO')
      ),
      actionLabel: t('CAPTAIN.OVERVIEW.READINESS.STEPS.KNOWLEDGE.ACTION'),
      editLabel: t('CAPTAIN.OVERVIEW.READINESS.STEPS.KNOWLEDGE.EDIT'),
      to: routeTo('captain_assistants_documents_index'),
    },
    {
      key: 'handoff',
      title: t('CAPTAIN.OVERVIEW.READINESS.STEPS.HANDOFF.TITLE'),
      summary: stepSummary(
        'handoff',
        handoffDoneSummary.value,
        t('CAPTAIN.OVERVIEW.READINESS.STEPS.HANDOFF.TODO')
      ),
      actionLabel: t('CAPTAIN.OVERVIEW.READINESS.STEPS.HANDOFF.ACTION'),
      editLabel: t('CAPTAIN.OVERVIEW.READINESS.STEPS.HANDOFF.EDIT'),
      to: routeTo('captain_assistants_settings_system_index'),
    },
    {
      key: 'tested',
      title: t('CAPTAIN.OVERVIEW.READINESS.STEPS.TESTED.TITLE'),
      summary: stepSummary(
        'tested',
        t('CAPTAIN.OVERVIEW.READINESS.STEPS.TESTED.DONE'),
        t('CAPTAIN.OVERVIEW.READINESS.STEPS.TESTED.TODO')
      ),
      actionLabel: t('CAPTAIN.OVERVIEW.READINESS.STEPS.TESTED.ACTION'),
      editLabel: t('CAPTAIN.OVERVIEW.READINESS.STEPS.TESTED.EDIT'),
      to: routeTo('captain_assistants_playground_index'),
    },
    {
      key: 'channel',
      title: t('CAPTAIN.OVERVIEW.READINESS.STEPS.CHANNEL.TITLE'),
      summary: stepSummary(
        'channel',
        t('CAPTAIN.OVERVIEW.READINESS.STEPS.CHANNEL.DONE', {
          channel: firstChannelName,
        }),
        t('CAPTAIN.OVERVIEW.READINESS.STEPS.CHANNEL.TODO')
      ),
      actionLabel: t('CAPTAIN.OVERVIEW.READINESS.STEPS.CHANNEL.ACTION'),
      editLabel: t('CAPTAIN.OVERVIEW.READINESS.STEPS.CHANNEL.EDIT'),
      to: routeTo('captain_assistants_inboxes_index'),
    },
  ].map(step => ({ ...step, state: stepStates.value[step.key] }));
});

const hasHandledConversations = computed(
  () => (metricStats.value?.conversations_handled?.current || 0) > 0
);
const isInitialLoading = computed(
  () => isFetchingFaqStats.value || channelsStatus.value === 'loading'
);
const isRunningAgent = computed(
  () =>
    readiness.value.completed === readiness.value.total ||
    inboxes.value.length > 0 ||
    hasHandledConversations.value
);
// A known open step shows the checklist; unknown steps alone show it only when nothing else would, so a failed
// status request never turns a running agent back into setup and never leaves the page blank.
const showReadinessChecklist = computed(
  () =>
    !isInitialLoading.value &&
    (readiness.value.hasOpenStep ||
      (readiness.value.hasUnknownStep && !isRunningAgent.value))
);

const channelStatusLabel = computed(() => {
  if (channelsStatus.value === 'failed') {
    return t('CAPTAIN.OVERVIEW.STATUS_LINE.UNKNOWN');
  }
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
    icon: 'i-lucide-message-square-dot',
    tone: 'blue',
    label: t('CAPTAIN.OVERVIEW.METRICS.HANDLED.LABEL'),
    hint: t('CAPTAIN.OVERVIEW.METRICS.HANDLED.HINT'),
    ...metricFor('conversations_handled', v => v.toLocaleString(), 'up'),
  },
  {
    key: 'autoResolution',
    metric: 'auto_resolution_rate',
    icon: 'i-lucide-circle-check-big',
    tone: 'teal',
    label: t('CAPTAIN.OVERVIEW.METRICS.AUTO_RESOLUTION.LABEL'),
    hint: t('CAPTAIN.OVERVIEW.METRICS.AUTO_RESOLUTION.HINT'),
    ...metricFor('auto_resolution_rate', v => `${v}%`, 'up', 'point'),
  },
  {
    key: 'hoursSaved',
    icon: 'i-lucide-clock',
    tone: 'violet',
    label: t('ANALYTICS.ESTIMATED_HOURS_SAVED'),
    hint: t('CAPTAIN.OVERVIEW.METRICS.HOURS_SAVED.HINT'),
    ...metricFor('hours_saved', formatDuration, 'up'),
  },
]);

const attentionText = (key, count) =>
  ({
    failedSources: {
      title: t(
        'CAPTAIN.OVERVIEW.NEEDS_ATTENTION.FAILED_SOURCES.TITLE',
        { count },
        count
      ),
      description: t(
        'CAPTAIN.OVERVIEW.NEEDS_ATTENTION.FAILED_SOURCES.DESCRIPTION'
      ),
      actionLabel: t('CAPTAIN.OVERVIEW.NEEDS_ATTENTION.FAILED_SOURCES.ACTION'),
    },
    unansweredQuestions: {
      title: t(
        'CAPTAIN.OVERVIEW.NEEDS_ATTENTION.UNANSWERED_QUESTIONS.TITLE',
        { count },
        count
      ),
      description: t(
        'CAPTAIN.OVERVIEW.NEEDS_ATTENTION.UNANSWERED_QUESTIONS.DESCRIPTION'
      ),
      actionLabel: t(
        'CAPTAIN.OVERVIEW.NEEDS_ATTENTION.UNANSWERED_QUESTIONS.ACTION'
      ),
    },
    pausedActions: {
      title: t(
        'CAPTAIN.OVERVIEW.NEEDS_ATTENTION.PAUSED_ACTIONS.TITLE',
        { count },
        count
      ),
      description: t(
        'CAPTAIN.OVERVIEW.NEEDS_ATTENTION.PAUSED_ACTIONS.DESCRIPTION'
      ),
      actionLabel: t('CAPTAIN.OVERVIEW.NEEDS_ATTENTION.PAUSED_ACTIONS.ACTION'),
    },
  })[key];

const ATTENTION_LINKS = {
  failedSources: {
    icon: 'i-lucide-circle-alert text-n-ruby-11',
    to: () =>
      routeTo('captain_assistants_documents_index', { filter: 'failed' }),
  },
  unansweredQuestions: {
    icon: 'i-lucide-circle-help text-n-amber-11',
    to: () => routeTo('captain_assistants_faq_suggestions'),
  },
  pausedActions: {
    icon: 'i-lucide-circle-pause text-n-amber-11',
    to: () => routeTo('captain_tools_index'),
  },
};

// null while the attention facts are unknown (loading or failed).
const attentionItems = computed(() => {
  const counts = attentionCounts(faqStats.value);
  if (!counts) return null;

  return counts.map(({ key, count }) => ({
    key,
    icon: ATTENTION_LINKS[key].icon,
    to: ATTENTION_LINKS[key].to(),
    ...attentionText(key, count),
  }));
});

const openReportPage = () =>
  router.push({
    name: 'analytics_ai_agent',
    params: { accountId: accountId.value },
    query: { period: selectedRange.value },
  });

const drilldown = ref({ metric: '', label: '', value: '' });
const isDrilldownOpen = ref(false);

const openDrilldown = metric => {
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
          :label="$t('ANALYTICS.VIEW_WORKSPACE_REPORT')"
          @click="openReportPage"
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
          class="overflow-hidden rounded-card bg-n-solid-2 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
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
                      completed: readiness.completed,
                      total: readiness.total,
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
                  v-if="step.state === STEP_STATES.DONE"
                  class="mt-0.5 shrink-0 size-5 i-lucide-check-circle-2 text-n-teal-11"
                />
                <span
                  v-else-if="step.state === STEP_STATES.UNKNOWN"
                  class="mt-0.5 shrink-0 size-5 i-lucide-circle-dashed text-n-slate-10"
                />
                <span
                  v-else
                  class="mt-0.5 grid shrink-0 size-5 place-content-center rounded-full border text-xs font-medium tabular-nums"
                  :class="
                    readiness.nextOpenKey === step.key
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
                v-if="step.state === STEP_STATES.UNKNOWN"
                type="button"
                size="sm"
                variant="faded"
                color="slate"
                :label="$t('CAPTAIN.OVERVIEW.RETRY')"
                @click="retryStatus"
              />
              <Button
                v-else-if="readiness.nextOpenKey === step.key"
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
                {{
                  step.state === STEP_STATES.DONE
                    ? step.editLabel
                    : step.actionLabel
                }}
              </RouterLink>
            </div>
          </div>
        </section>

        <!-- Running AI agent view -->
        <template v-if="isRunningAgent">
          <!-- One status line with edit links -->
          <div
            class="flex flex-wrap items-center justify-between gap-3 px-4 py-3 rounded-card bg-n-solid-2 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
          >
            <div
              class="flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-n-slate-12"
            >
              <span
                class="shrink-0 size-2 rounded-full"
                :class="
                  channelsStatus === 'failed'
                    ? 'bg-n-slate-8'
                    : inboxes.length > 0
                      ? 'bg-n-teal-9'
                      : 'bg-n-amber-9'
                "
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
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
            <MetricTile
              v-for="metric in primaryMetrics"
              :key="metric.key"
              :icon="metric.icon"
              :tone="metric.tone"
              :label="metric.label"
              :value="metric.value"
              :change="metric.trend"
              :change-tone="
                metric.trendGood === true
                  ? 'good'
                  : metric.trendGood === false
                    ? 'bad'
                    : 'neutral'
              "
              :hint="metric.hint"
              hover-hint
              :is-loading="isFetchingMetrics"
              :clickable="
                canDrilldown && Boolean(metric.metric) && !isFetchingMetrics
              "
              @click="openDrilldown(metric)"
            />
          </div>

          <!-- Short Needs attention list -->
          <section
            v-if="
              isFetchingFaqStats || !attentionItems || attentionItems.length
            "
            class="overflow-hidden rounded-card bg-n-solid-2 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
          >
            <div class="px-5 py-3.5 border-b border-n-weak">
              <h2 class="m-0 text-sm font-medium text-n-slate-12">
                {{ $t('CAPTAIN.OVERVIEW.NEEDS_ATTENTION.TITLE') }}
              </h2>
            </div>

            <div
              v-if="isFetchingFaqStats"
              class="flex flex-col gap-3 px-5 py-4"
              aria-busy="true"
            >
              <span
                v-for="n in 2"
                :key="n"
                class="h-8 w-full animate-pulse rounded bg-n-alpha-2"
              />
            </div>

            <div
              v-else-if="!attentionItems"
              role="alert"
              class="flex flex-wrap items-center justify-between gap-3 px-5 py-4"
            >
              <div class="flex items-start gap-2.5 min-w-0 text-sm">
                <span
                  class="mt-0.5 shrink-0 size-4 i-lucide-circle-alert text-n-ruby-11"
                />
                <div class="min-w-0">
                  <div class="font-medium text-n-slate-12">
                    {{ $t('CAPTAIN.OVERVIEW.NEEDS_ATTENTION.FAILED.TITLE') }}
                  </div>
                  <div class="text-n-slate-11">
                    {{
                      $t('CAPTAIN.OVERVIEW.NEEDS_ATTENTION.FAILED.DESCRIPTION')
                    }}
                  </div>
                </div>
              </div>
              <Button
                type="button"
                variant="faded"
                color="slate"
                size="sm"
                :label="$t('CAPTAIN.OVERVIEW.RETRY')"
                @click="fetchFaqStats"
              />
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

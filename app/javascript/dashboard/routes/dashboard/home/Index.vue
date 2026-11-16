<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { differenceInCalendarDays, format, subDays } from 'date-fns';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import CaptainHomeAPI from 'dashboard/api/captain/home';
import { useHomeSetupProgress } from './useHomeSetupProgress';
import {
  METRICS,
  PERIODS,
  metricChange,
  metricValue,
  needItems,
} from './homeView';
import HomeDashboard from './components/HomeDashboard.vue';

const STATUS_DONE = 'done';

const { t } = useI18n();
const route = useRoute();
const { isAdmin } = useAdmin();
const { run, isPending } = useAbortableRequest();

const now = new Date();
const dateRange = ref([subDays(now, PERIODS[0] - 1), now]);
const rangeDays = computed(
  () => differenceInCalendarDays(dateRange.value[1], dateRange.value[0]) + 1
);
const summary = ref(null);
const hasError = ref(false);
const isLoading = computed(
  () => isPending.value || (!summary.value && !hasError.value)
);

const { progress: setupProgress } = useHomeSetupProgress(summary);
const showSetup = computed(
  () => isAdmin.value && summary.value && !setupProgress.value.isComplete
);

const metricLabels = computed(() => ({
  ai_conversations: t('HOME.V2.METRICS.AI_CONVERSATIONS'),
  resolved: t('HOME.V2.METRICS.RESOLVED'),
  handed: t('HOME.V2.METRICS.HANDED'),
}));

const metrics = computed(() =>
  METRICS.filter(config => metricLabels.value[config.key]).map(config => {
    const metric = summary.value?.metrics?.[config.key] || {
      value: null,
      previous: null,
    };
    const change = metricChange(config, metric, t);
    return {
      key: config.key,
      label: metricLabels.value[config.key],
      value: metricValue(config, metric.value),
      change: change.text,
      changeTone: change.tone,
    };
  })
);

const needs = computed(() => needItems(summary.value?.needs || [], t));

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
        startDate: format(dateRange.value[0], 'yyyy-MM-dd'),
        endDate: format(dateRange.value[1], 'yyyy-MM-dd'),
        timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      })
    );
    if (response) summary.value = response.data;
  } catch {
    hasError.value = true;
  }
};

const selectDates = dates => {
  dateRange.value = dates;
  loadSummary();
};

watch(
  () => route.params.accountId,
  () => {
    summary.value = null;
    loadSummary();
  },
  { immediate: true }
);
</script>

<template>
  <HomeDashboard
    :period="rangeDays"
    :date-range="dateRange"
    :summary="summary"
    :metrics="metrics"
    :needs="needs"
    :project-status="projectStatus"
    :setup-progress="showSetup ? setupProgress : null"
    :is-loading="isLoading"
    :has-error="hasError"
    @select-dates="selectDates"
    @retry="loadSummary"
  />
</template>

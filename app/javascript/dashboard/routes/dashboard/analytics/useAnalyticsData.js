import { ref, watch } from 'vue';
import CaptainHomeAPI from 'dashboard/api/captain/home';
import ReportsAPI from 'dashboard/api/reports';
import SummaryReportsAPI from 'dashboard/api/summaryReports';
import { periodWindow } from './analyticsView';

const TIMEZONE_OFFSET = -new Date().getTimezoneOffset() / 60;

// Everything the Overview needs for one period, in three parallel requests: the AI agent's activity (Home), the
// conversation summary with the period before, and the per-agent summary. A newer period wins over a slower one.
export function useAnalyticsData(period) {
  const activity = ref(null);
  const report = ref(null);
  const agentSummary = ref([]);
  const isLoading = ref(true);
  const hasError = ref(false);
  let token = 0;

  const load = async () => {
    token += 1;
    const current = token;
    isLoading.value = true;
    hasError.value = false;
    const { since, until } = periodWindow(period.value);
    try {
      const [home, summary, agents] = await Promise.all([
        CaptainHomeAPI.get({
          period: period.value,
          timezoneOffset: TIMEZONE_OFFSET,
        }),
        ReportsAPI.getSummary(since, until, 'account'),
        SummaryReportsAPI.getAgentReports({ since, until }),
      ]);
      if (current !== token) return;
      activity.value = home.data;
      report.value = summary.data;
      agentSummary.value = agents.data;
    } catch {
      if (current === token) hasError.value = true;
    } finally {
      if (current === token) isLoading.value = false;
    }
  };

  watch(period, load, { immediate: true });

  return { activity, report, agentSummary, isLoading, hasError, reload: load };
}

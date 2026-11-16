import { ref, watch } from 'vue';
import CaptainHomeAPI from 'dashboard/api/captain/home';
import ReportsAPI from 'dashboard/api/reports';
import SummaryReportsAPI from 'dashboard/api/summaryReports';
import { periodWindow, previousWindow } from './analyticsView';

const TIMEZONE_OFFSET = -new Date().getTimezoneOffset() / 60;

// The requests the views share. Each takes the period's window and returns the response data.
export const LOADERS = {
  // The AI agent's activity per day against the period before (Captain::HomeActivityBuilder, via Home).
  activity: ({ period }) =>
    CaptainHomeAPI.get({
      range: String(period),
      timezoneOffset: TIMEZONE_OFFSET,
    }),
  // Conversation numbers with the same span before (`previous`).
  report: ({ since, until }) => ReportsAPI.getSummary(since, until, 'account'),
  agents: ({ since, until }) =>
    SummaryReportsAPI.getAgentReports({ since, until }),
};

// Loads what one view needs for the period, in parallel: `loaders` maps a name to a request (see LOADERS). A newer
// period wins over a slower one; independent failures retain successful sections and expose a retry.
export function useAnalyticsData(period, loaders) {
  const data = ref({});
  const isLoading = ref(true);
  const hasError = ref(false);
  const failures = ref({});
  let token = 0;

  const load = async () => {
    token += 1;
    const current = token;
    isLoading.value = true;
    hasError.value = false;
    failures.value = {};
    data.value = {};
    const window = periodWindow(period.value);
    const request = {
      ...window,
      previous: previousWindow(window, period.value),
      period: period.value,
    };
    try {
      const names = Object.keys(loaders);
      const responses = await Promise.allSettled(
        names.map(name => loaders[name](request))
      );
      if (current !== token) return;
      data.value = Object.fromEntries(
        responses.flatMap((response, index) =>
          response.status === 'fulfilled'
            ? [[names[index], response.value.data]]
            : []
        )
      );
      failures.value = Object.fromEntries(
        names.map((name, index) => [
          name,
          responses[index].status === 'rejected',
        ])
      );
      hasError.value = names.every(name => failures.value[name]);
    } catch {
      if (current === token) hasError.value = true;
    } finally {
      if (current === token) isLoading.value = false;
    }
  };

  watch(period, load, { immediate: true });

  return { data, isLoading, hasError, failures, reload: load };
}

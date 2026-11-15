import { metricChange, metricValue } from '../home/homeView';

// Turns the Home activity (Captain::HomeActivityBuilder), the conversation report summary and the per-agent summary
// into what the Analytics tabs show. Pure, so it is tested on its own.

export const PERIODS = [7, 30];
export const DEFAULT_PERIOD = PERIODS[0];

// The period in the URL (?period=30); anything else falls back to the default.
export const periodFromQuery = value => {
  const days = Number(value);
  return PERIODS.includes(days) ? days : DEFAULT_PERIOD;
};

// The same window as the Home activity: the last `days` calendar days, today included, as unix seconds.
export const periodWindow = (days, now = new Date()) => {
  const start = new Date(now);
  start.setHours(0, 0, 0, 0);
  start.setDate(start.getDate() - (days - 1));
  return {
    since: Math.floor(start.getTime() / 1000),
    until: Math.floor(now.getTime() / 1000),
  };
};

const MINUTE = 60;
const HOUR = 60 * MINUTE;

// "45 s", "4 min", "2 h 10 min"; a dash when there is nothing to average.
export const durationText = (seconds, t) => {
  if (!seconds) return '–';
  if (seconds < MINUTE) {
    return t('ANALYTICS.DURATION.SECONDS', { count: Math.round(seconds) });
  }
  if (seconds < HOUR) {
    return t('ANALYTICS.DURATION.MINUTES', {
      count: Math.round(seconds / MINUTE),
    });
  }
  const hours = Math.floor(seconds / HOUR);
  const minutes = Math.round((seconds % HOUR) / MINUTE);
  return minutes
    ? t('ANALYTICS.DURATION.HOURS_MINUTES', { hours, minutes })
    : t('ANALYTICS.DURATION.HOURS', { count: hours });
};

// How each number is compared with the period before.
export const METRICS = {
  conversations: {
    icon: 'i-lucide-messages-square',
    tone: 'blue',
    change: 'percent',
  },
  ai_conversations: { icon: 'i-lucide-bot', tone: 'blue', change: 'percent' },
  resolved: {
    icon: 'i-lucide-circle-check-big',
    tone: 'teal',
    change: 'points',
    unit: '%',
  },
  handed: {
    icon: 'i-lucide-users',
    tone: 'amber',
    change: 'count',
    lowerIsBetter: true,
  },
  first_reply: {
    icon: 'i-lucide-timer',
    tone: 'violet',
    change: 'percent',
    lowerIsBetter: true,
    duration: true,
  },
  team_solved: {
    icon: 'i-lucide-check-check',
    tone: 'teal',
    change: 'percent',
  },
  rating: { icon: 'i-lucide-star', tone: 'amber', change: 'decimal' },
};

const EMPTY = { value: null, previous: null, points: [] };

// Every Overview number as { value, previous, points } from the two summaries.
export const overviewMetrics = (activity, report) => {
  const home = activity?.metrics || {};
  const days = activity?.days || [];
  const previous = report?.previous || {};
  return {
    conversations: {
      value: report ? report.conversations_count : null,
      previous: report ? previous.conversations_count : null,
      points: days.map(day => day.ai + day.team),
    },
    ai_conversations: home.ai_conversations || EMPTY,
    resolved: home.resolved || EMPTY,
    handed: home.handed || EMPTY,
    first_reply: {
      value: report ? report.avg_first_response_time : null,
      previous: report ? previous.avg_first_response_time : null,
      points: [],
    },
    team_solved: {
      value: report ? report.resolutions_count : null,
      previous: report ? previous.resolutions_count : null,
      points: [],
    },
    rating: home.rating || EMPTY,
  };
};

// One number ready for a tile: formatted value, change line and its tone.
export const metricView = (key, metric, t) => {
  const config = METRICS[key];
  const change = metricChange(config, metric, t);
  return {
    key,
    icon: config.icon,
    tone: config.tone,
    value: config.duration
      ? durationText(metric.value, t)
      : metricValue(config, metric.value),
    change: change.text,
    changeTone: change.tone,
    points: (metric.points || []).filter(point => point !== null),
  };
};

// Agents with conversations in the period, busiest first, with names from the agents store.
export const teamRows = (agentSummary, agents) => {
  const names = Object.fromEntries(
    (agents || []).map(agent => [agent.id, agent.available_name || agent.name])
  );
  return (agentSummary || [])
    .filter(row => row.conversations_count > 0 && names[row.id])
    .map(row => ({
      id: row.id,
      name: names[row.id],
      conversations: row.conversations_count,
      solved: row.resolved_conversations_count,
      firstReply: row.avg_first_response_time,
    }))
    .sort((first, second) => second.conversations - first.conversations);
};

// The day with the most conversations, or null when the period is empty.
export const busiestDay = days =>
  days.reduce(
    (best, day) =>
      day.ai + day.team > (best ? best.ai + best.team : 0) ? day : best,
    null
  );

// A round top for a chart axis, at least the largest value, and three gridlines that are whole numbers.
export const chartScale = max => {
  const power = 10 ** Math.max(Math.floor(Math.log10(Math.max(max, 1))), 0);
  const top = [2, 4, 6, 8, 10]
    .map(step => step * power)
    .find(step => step >= max);
  return { top, ticks: [top, top / 2, 0] };
};

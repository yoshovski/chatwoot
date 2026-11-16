import { metricChange, metricValue } from '../home/homeView';

// Turns the Home activity (Captain::HomeActivityBuilder), the conversation report summary and the per-agent summary
// into what the Analytics tabs show. Pure, so it is tested on its own.

export const PERIODS = [7, 30, 90];
export const CALENDAR_PERIODS = [
  'this_week',
  'last_week',
  'this_month',
  'last_month',
];
export const DEFAULT_PERIOD = PERIODS[0];

export const periodFromQuery = value => {
  if (CALENDAR_PERIODS.includes(value)) return value;
  return PERIODS.includes(Number(value)) ? Number(value) : DEFAULT_PERIOD;
};

export const isSupportedPeriod = value =>
  value === undefined ||
  [...PERIODS.map(String), ...CALENDAR_PERIODS].includes(value);

// Matches Captain::AssistantStatsWindow, including Sunday-based calendar weeks.
export const periodWindow = (period, now = new Date()) => {
  const start = new Date(now);
  const end = new Date(now);
  if (CALENDAR_PERIODS.includes(period)) {
    start.setHours(0, 0, 0, 0);
    if (period.endsWith('week')) {
      start.setDate(start.getDate() - start.getDay());
      if (period === 'last_week') {
        end.setTime(start.getTime() - 1);
        start.setDate(start.getDate() - 7);
      }
    } else {
      start.setDate(1);
      if (period === 'last_month') {
        end.setTime(start.getTime() - 1);
        start.setMonth(start.getMonth() - 1);
      }
    }
  } else {
    start.setDate(start.getDate() - Number(period));
  }
  return {
    since: Math.floor(start.getTime() / 1000),
    until: Math.floor(end.getTime() / 1000),
  };
};

const MINUTE = 60;
const HOUR = 60 * MINUTE;

// "45 s", "4 min", "2 h 10 min"; a dash when there is nothing to average.
export const durationText = (seconds, t) => {
  if (seconds === null || seconds === undefined) return '–';
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

// The span of the same length right before a window.
export const previousWindow = ({ since, until }, period) => {
  const start = new Date(since * 1000);
  const end = new Date(until * 1000);
  if (period === 'this_month' || period === 'last_month') {
    const monthStart = new Date(start.getFullYear(), start.getMonth(), 1);
    const previousStart = new Date(
      start.getFullYear(),
      start.getMonth() - 1,
      1
    );
    const previousEnd = new Date(monthStart.getTime() - 1);
    return {
      since: Math.floor(previousStart.getTime() / 1000),
      until: Math.floor(
        (period === 'last_month'
          ? previousEnd.getTime()
          : Math.min(
              previousStart.getTime() + end.getTime() - start.getTime(),
              previousEnd.getTime()
            )) / 1000
      ),
    };
  }
  if (period) {
    const days = CALENDAR_PERIODS.includes(period) ? 7 : Number(period);
    start.setDate(start.getDate() - days);
    end.setDate(end.getDate() - days);
    return { since: Math.floor(start / 1000), until: Math.floor(end / 1000) };
  }
  return { since: since - (until - since), until: since };
};

// How each number looks and is compared with the period before.
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
    neutralTrend: true,
  },
  product_answers: {
    icon: 'i-lucide-shopping-bag',
    tone: 'violet',
    change: 'percent',
  },
  first_reply: {
    icon: 'i-lucide-timer',
    tone: 'violet',
    change: 'percent',
    lowerIsBetter: true,
    duration: true,
  },
  resolution_time: {
    icon: 'i-lucide-hourglass',
    tone: 'blue',
    change: 'percent',
    lowerIsBetter: true,
    duration: true,
  },
  team_solved: {
    icon: 'i-lucide-check-check',
    tone: 'teal',
    change: 'percent',
  },
  rating: {
    icon: 'i-lucide-star',
    tone: 'amber',
    change: 'decimal',
    unit: '/5',
  },
  ratings_count: {
    icon: 'i-lucide-message-square-heart',
    tone: 'blue',
    change: 'percent',
  },
  happy_share: {
    icon: 'i-lucide-smile',
    tone: 'teal',
    change: 'points',
    unit: '%',
  },
  reply_share: {
    icon: 'i-lucide-mail-check',
    tone: 'violet',
    change: 'points',
    unit: '%',
  },
};

const metricDefinitions = t => ({
  conversations: t('ANALYTICS.DEFINITIONS.CONVERSATIONS'),
  ai_conversations: t('ANALYTICS.DEFINITIONS.AI_CONVERSATIONS'),
  resolved: t('ANALYTICS.DEFINITIONS.RESOLVED'),
  handed: t('ANALYTICS.DEFINITIONS.HANDED'),
  product_answers: t('ANALYTICS.DEFINITIONS.PRODUCT_ANSWERS'),
  first_reply: t('ANALYTICS.DEFINITIONS.FIRST_REPLY'),
  resolution_time: t('ANALYTICS.DEFINITIONS.RESOLUTION_TIME'),
  team_solved: t('ANALYTICS.DEFINITIONS.TEAM_SOLVED'),
  rating: t('ANALYTICS.DEFINITIONS.RATING'),
  ratings_count: t('ANALYTICS.DEFINITIONS.RATINGS_COUNT'),
  happy_share: t('ANALYTICS.DEFINITIONS.HAPPY_SHARE'),
  reply_share: t('ANALYTICS.DEFINITIONS.REPLY_SHARE'),
});

const EMPTY = { value: null, previous: null, points: [] };

const pair = (current, previous, key) => ({
  value: current ? current[key] : null,
  previous: previous ? previous[key] : null,
  points: [],
});

// A whole percentage, at most 100; nothing to share without a whole.
const share = (part, whole) =>
  whole ? Math.min(Math.round((part / whole) * 100), 100) : null;

// Ratings of 4 or 5 as a share of all ratings; `ratings_count` is { rating: count }.
const happyShare = csat => {
  if (!csat) return null;
  const counts = csat.ratings_count || {};
  return share((counts[4] || 0) + (counts[5] || 0), csat.total_count);
};

// Every number the views show, as { value, previous, points }, from whatever the view loaded.
export const analyticsMetrics = ({
  activity,
  report,
  csat,
  csatPrevious,
} = {}) => {
  const home = activity?.metrics || {};
  const days = activity?.days || [];
  return {
    conversations: {
      ...pair(report, report?.previous, 'conversations_count'),
      points: days.map(day => day.ai + day.team),
    },
    ai_conversations: home.ai_conversations || EMPTY,
    resolved:
      home.ai_conversations?.value === 0
        ? { ...EMPTY, previous: home.resolved?.previous }
        : home.resolved || EMPTY,
    handed: home.handed || EMPTY,
    product_answers: home.product_answers || EMPTY,
    first_reply: pair(report, report?.previous, 'avg_first_response_time'),
    resolution_time: pair(report, report?.previous, 'avg_resolution_time'),
    team_solved: pair(report, report?.previous, 'resolutions_count'),
    rating: home.rating || EMPTY,
    ratings_count: pair(csat, csatPrevious, 'total_count'),
    happy_share: {
      value: happyShare(csat),
      previous: happyShare(csatPrevious),
      points: [],
    },
    reply_share: {
      value: csat
        ? share(csat.total_count, csat.total_sent_messages_count)
        : null,
      previous: csatPrevious
        ? share(
            csatPrevious.total_count,
            csatPrevious.total_sent_messages_count
          )
        : null,
      points: [],
    },
  };
};

// One number ready for a tile: label, formatted value, change line and its tone.
export const metricView = (key, metric, label, t) => {
  const config = METRICS[key];
  const change = metricChange(config, metric, t);
  return {
    key,
    label,
    icon: config.icon,
    tone: config.tone,
    value: config.duration
      ? durationText(metric.value, t)
      : metricValue(config, metric.value),
    change:
      change.text ||
      (metric.value !== null && metric.value !== undefined
        ? t('ANALYTICS.NO_COMPARISON')
        : ''),
    changeTone: config.neutralTrend ? 'neutral' : change.tone,
    hint: metricDefinitions(t)[key],
    points: (metric.points || []).filter(point => point !== null),
  };
};

const byConversations = (first, second) =>
  second.conversations - first.conversations;

// People with conversations in the period, busiest first, named from the agents store.
export const peopleRows = (agentSummary, agents) => {
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
    .sort(byConversations);
};

// Teams with conversations in the period, busiest first, named from the teams store.
export const teamRows = (teamSummary, teams) => {
  const names = Object.fromEntries(
    (teams || []).map(team => [team.id, team.name])
  );
  return (teamSummary || [])
    .filter(row => row.conversations_count > 0 && names[row.id])
    .map(row => ({
      id: row.id,
      name: names[row.id],
      conversations: row.conversations_count,
      solved: row.resolved_conversations_count,
      firstReply: row.avg_first_response_time,
    }))
    .sort(byConversations);
};

// The chart's days: [{ date, values }] for the given series of each Home day.
export const chartDays = (days, pick) =>
  (days || []).map(day => ({ date: day.date, values: pick(day) }));

// The AI agent's day: conversations that stayed with it, then the ones it handed to the team.
export const aiDays = activity => {
  const handed = activity?.metrics?.handed?.points || [];
  return (activity?.days || []).map((day, index) => {
    const handedToday = handed[index] || 0;
    return {
      date: day.date,
      values: [Math.max(day.ai - handedToday, 0), handedToday],
    };
  });
};

// Ratings 5 to 1 with their count and share of all ratings.
export const ratingRows = csat => {
  const counts = csat?.ratings_count || {};
  const total = csat?.total_count || 0;
  return [5, 4, 3, 2, 1].map(rating => ({
    rating,
    count: counts[rating] || 0,
    share: share(counts[rating] || 0, total) || 0,
  }));
};

// The latest ratings that came with a comment.
export const commentRows = (responses, limit = 4) =>
  (responses || [])
    .filter(response => response.feedback_message)
    .slice(0, limit)
    .map(response => ({
      id: response.id,
      rating: response.rating,
      comment: response.feedback_message,
      name: response.contact?.name || '',
      at: response.created_at,
      conversationId: response.conversation_id,
    }));

// A round top for a chart axis, at least the largest value, and three gridlines that are whole numbers.
export const chartScale = max => {
  const power = 10 ** Math.max(Math.floor(Math.log10(Math.max(max, 1))), 0);
  const top = [2, 4, 6, 8, 10]
    .map(step => step * power)
    .find(step => step >= max);
  return { top, ticks: [top, top / 2, 0] };
};

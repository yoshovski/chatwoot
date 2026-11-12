import { dynamicTime } from 'shared/helpers/timeHelper';

// Turns the Home summary (Captain::HomeSummaryBuilder) into what the cards show. Pure, so it is tested on its own.

export const PERIODS = [7, 30];

export const METRICS = [
  {
    key: 'ai_conversations',
    icon: 'i-lucide-bot',
    tone: 'blue',
    change: 'percent',
  },
  {
    key: 'resolved',
    icon: 'i-lucide-circle-check-big',
    tone: 'teal',
    change: 'points',
    unit: '%',
  },
  {
    key: 'handed',
    icon: 'i-lucide-users',
    tone: 'amber',
    change: 'count',
    lowerIsBetter: true,
  },
  { key: 'rating', icon: 'i-lucide-star', tone: 'violet', change: 'decimal' },
  {
    key: 'product_answers',
    icon: 'i-lucide-shopping-bag',
    tone: 'blue',
    change: 'percent',
  },
];

const STATUS_PILLS = {
  live: 'live',
  learning: 'learning',
  paused: 'paused',
  limit_reached: 'limit',
  needs_attention: 'attention',
};

export const statusPill = (status, t) => ({
  status: STATUS_PILLS[status],
  label: {
    live: t('HOME.V2.STATUS_PILL.LIVE'),
    learning: t('HOME.V2.STATUS_PILL.LEARNING'),
    paused: t('HOME.V2.STATUS_PILL.PAUSED'),
    limit_reached: t('HOME.V2.STATUS_PILL.LIMIT'),
    needs_attention: t('HOME.V2.STATUS_PILL.ATTENTION'),
  }[status],
});

const changeAmount = (config, value, previous) => {
  if (config.change === 'percent') {
    return previous ? Math.round(((value - previous) / previous) * 100) : null;
  }
  const difference = value - previous;
  return config.change === 'decimal'
    ? Math.round(difference * 10) / 10
    : Math.round(difference);
};

// "▲ 12%" against the period before (the card says so in its tooltip). Nothing without two numbers to compare.
export const metricChange = (config, metric, t) => {
  const { value, previous } = metric;
  if (value === null || previous === null || (!value && !previous)) {
    return { text: '', tone: 'neutral' };
  }
  const amount = changeAmount(config, value, previous);
  if (amount === null) return { text: '', tone: 'neutral' };
  if (amount === 0) {
    return {
      text: t('HOME.V2.CHANGE.SAME'),
      tone: 'neutral',
    };
  }
  const better = config.lowerIsBetter ? amount < 0 : amount > 0;
  const size = Math.abs(amount);
  const amountText = {
    percent: t('HOME.V2.CHANGE.PERCENT', { amount: size }),
    points: t('HOME.V2.CHANGE.POINTS', { amount: size }, size),
    count: String(size),
    decimal: String(size),
  }[config.change];
  const params = { amount: amountText };
  return {
    text:
      amount > 0
        ? t('HOME.V2.CHANGE.UP', params)
        : t('HOME.V2.CHANGE.DOWN', params),
    tone: better ? 'good' : 'bad',
  };
};

export const metricValue = (config, value) => {
  if (value === null || value === undefined) return '–';
  return config.unit ? `${value}${config.unit}` : value;
};

// Weekday names for a week, day numbers for a month.
export const dayLabels = (days, period, locale) =>
  days.map(day => {
    const date = new Date(`${day.date}T12:00:00`);
    return {
      label:
        period === 7
          ? date.toLocaleDateString(locale, { weekday: 'short' })
          : String(date.getDate()),
      ai: day.ai,
      team: day.team,
    };
  });

const conversationRoute = id => ({
  name: 'inbox_conversation',
  params: { conversation_id: id },
});
const assistantRoute = (name, assistantId) => ({
  name,
  params: { assistantId },
});

const NEED_VIEWS = {
  handoff: (item, t) => ({
    title: t('HOME.V2.NEEDS.HANDOFF', {
      name: item.name || t('HOME.V2.NEEDS.SOMEONE'),
    }),
    hint: t('HOME.V2.NEEDS.HANDOFF_HINT', {
      inbox: item.inbox,
      time: dynamicTime(item.at),
    }),
    action: t('HOME.V2.NEEDS.REPLY'),
    to: conversationRoute(item.id),
  }),
  gap: (item, t) => ({
    title: t('HOME.V2.NEEDS.GAP', { question: item.question }),
    hint: t('HOME.V2.NEEDS.GAP_HINT', { count: item.count }, item.count),
    action: t('HOME.V2.NEEDS.ADD_ANSWER'),
    to: assistantRoute('captain_assistants_faq_suggestions', item.assistant_id),
  }),
  failed_action: (item, t) =>
    item.kind === 'connection'
      ? {
          title: t('HOME.V2.NEEDS.CONNECTION', { name: item.name }),
          hint: t('HOME.V2.NEEDS.FAILED_HINT', { time: dynamicTime(item.at) }),
          action: t('HOME.V2.NEEDS.FIX'),
          to: {
            name: 'captain_assistants_index',
            params: { navigationPath: 'captain_tools_connections' },
          },
        }
      : {
          title:
            item.kind === 'follow_up_email'
              ? t('HOME.V2.NEEDS.FOLLOW_UP_EMAIL')
              : t('HOME.V2.NEEDS.FOLLOW_UP_MESSAGE'),
          hint: t('HOME.V2.NEEDS.CONVERSATION_HINT', {
            id: item.id,
            time: dynamicTime(item.at),
          }),
          action: t('HOME.V2.NEEDS.OPEN'),
          to: conversationRoute(item.id),
        },
  failed_sync: (item, t) => ({
    title: t('HOME.V2.NEEDS.SYNC', { name: item.name }),
    hint: item.at
      ? t('HOME.V2.NEEDS.SYNC_HINT', { time: dynamicTime(item.at) })
      : '',
    action: t('HOME.V2.NEEDS.FIX'),
    to: assistantRoute('captain_assistants_documents_index', item.assistant_id),
  }),
  channel: (item, t) => ({
    title: t('HOME.V2.NEEDS.CHANNEL', { name: item.name }),
    hint: t('HOME.V2.NEEDS.CHANNEL_HINT'),
    action: t('HOME.V2.NEEDS.RECONNECT'),
    to: { name: 'settings_inbox_show', params: { inboxId: item.id } },
  }),
};

export const needItems = (needs, t) =>
  needs.map(item => ({ key: item.key, ...NEED_VIEWS[item.key](item, t) }));

import {
  aiDays,
  analyticsMetrics,
  chartScale,
  commentRows,
  durationText,
  metricView,
  peopleRows,
  periodFromQuery,
  periodWindow,
  previousWindow,
  ratingRows,
  teamRows,
} from '../analyticsView';

const t = (key, params = {}) =>
  Object.keys(params).length ? `${key} ${JSON.stringify(params)}` : key;

describe('periodFromQuery', () => {
  it('accepts 7 and 30 and falls back to 7', () => {
    expect(periodFromQuery('30')).toBe(30);
    expect(periodFromQuery('7')).toBe(7);
    expect(periodFromQuery('90')).toBe(7);
    expect(periodFromQuery(undefined)).toBe(7);
  });
});

describe('periodWindow and previousWindow', () => {
  it('starts at midnight of the first day and ends now', () => {
    const now = new Date(2026, 10, 15, 14, 30);
    const window = periodWindow(7, now);

    expect(new Date(window.since * 1000)).toEqual(new Date(2026, 10, 9));
    expect(window.until).toBe(Math.floor(now.getTime() / 1000));
  });

  it('takes the same span right before', () => {
    expect(previousWindow({ since: 100, until: 160 })).toEqual({
      since: 40,
      until: 100,
    });
  });
});

describe('durationText', () => {
  it('uses seconds, minutes, then hours and minutes', () => {
    expect(durationText(45, t)).toBe('ANALYTICS.DURATION.SECONDS {"count":45}');
    expect(durationText(480, t)).toBe('ANALYTICS.DURATION.MINUTES {"count":8}');
    expect(durationText(3720, t)).toBe(
      'ANALYTICS.DURATION.HOURS_MINUTES {"hours":1,"minutes":2}'
    );
    expect(durationText(7200, t)).toBe('ANALYTICS.DURATION.HOURS {"count":2}');
  });

  it('shows a dash with nothing to average', () => {
    expect(durationText(null, t)).toBe('–');
  });
});

describe('analyticsMetrics', () => {
  const report = {
    conversations_count: 96,
    avg_first_response_time: 480,
    avg_resolution_time: 3600,
    resolutions_count: 18,
    previous: {
      conversations_count: 63,
      avg_first_response_time: 470,
      avg_resolution_time: 3800,
      resolutions_count: 18,
    },
  };
  const activity = {
    metrics: { resolved: { value: 69, previous: 72, points: [70, 68] } },
    days: [
      { date: '2026-11-14', ai: 9, team: 2 },
      { date: '2026-11-15', ai: 7, team: 2 },
    ],
  };
  const csat = {
    total_count: 17,
    ratings_count: { 5: 6, 4: 7, 3: 3, 2: 1 },
    total_sent_messages_count: 34,
  };
  const csatPrevious = {
    total_count: 26,
    ratings_count: { 5: 10, 4: 8 },
    total_sent_messages_count: 40,
  };

  it('takes conversation numbers from the report with the period before', () => {
    const metrics = analyticsMetrics({ activity, report });

    expect(metrics.conversations).toEqual({
      value: 96,
      previous: 63,
      points: [11, 9],
    });
    expect(metrics.first_reply.value).toBe(480);
    expect(metrics.resolution_time.previous).toBe(3800);
    expect(metrics.resolved.value).toBe(69);
  });

  it('works out rating shares from the rating counts', () => {
    const metrics = analyticsMetrics({ csat, csatPrevious });

    expect(metrics.ratings_count).toMatchObject({ value: 17, previous: 26 });
    expect(metrics.happy_share).toMatchObject({ value: 76, previous: 69 });
    expect(metrics.reply_share).toMatchObject({ value: 50, previous: 65 });
  });

  it('leaves numbers empty until they are loaded', () => {
    const metrics = analyticsMetrics({});

    expect(metrics.conversations.value).toBeNull();
    expect(metrics.happy_share.value).toBeNull();
    expect(metrics.rating).toEqual({ value: null, previous: null, points: [] });
  });

  it('never shows more than 100 % of customers rating', () => {
    const metrics = analyticsMetrics({
      csat: {
        total_count: 17,
        ratings_count: {},
        total_sent_messages_count: 1,
      },
    });

    expect(metrics.reply_share.value).toBe(100);
  });
});

describe('metricView', () => {
  it('formats durations and marks a slower reply as bad', () => {
    const view = metricView(
      'first_reply',
      { value: 480, previous: 400, points: [] },
      'Time to first reply',
      t
    );

    expect(view.value).toBe('ANALYTICS.DURATION.MINUTES {"count":8}');
    expect(view.changeTone).toBe('bad');
    expect(view.label).toBe('Time to first reply');
  });
});

describe('peopleRows and teamRows', () => {
  it('keeps people with conversations, busiest first, with their names', () => {
    const rows = peopleRows(
      [
        { id: 1, conversations_count: 3, resolved_conversations_count: 2 },
        { id: 2, conversations_count: 9, avg_first_response_time: 540 },
        { id: 3, conversations_count: 0 },
      ],
      [
        { id: 1, name: 'John' },
        { id: 2, available_name: 'Omar', name: 'Omar Reyes' },
        { id: 3, name: 'Ivy' },
      ]
    );

    expect(rows.map(row => [row.name, row.conversations])).toEqual([
      ['Omar', 9],
      ['John', 3],
    ]);
    expect(rows[0].firstReply).toBe(540);
  });

  it('names teams from the teams store', () => {
    const rows = teamRows(
      [{ id: 4, conversations_count: 10 }],
      [{ id: 4, name: 'shipping' }]
    );

    expect(rows).toMatchObject([{ name: 'shipping', conversations: 10 }]);
  });
});

describe('aiDays', () => {
  it('splits each day into stayed with the AI agent and handed on', () => {
    const days = aiDays({
      days: [
        { date: '2026-11-14', ai: 10, team: 3 },
        { date: '2026-11-15', ai: 1, team: 0 },
      ],
      metrics: { handed: { points: [3, 2] } },
    });

    expect(days).toEqual([
      { date: '2026-11-14', values: [7, 3] },
      { date: '2026-11-15', values: [0, 2] },
    ]);
  });
});

describe('ratingRows and commentRows', () => {
  it('lists 5 to 1 stars with count and share', () => {
    const rows = ratingRows({ total_count: 4, ratings_count: { 5: 3, 1: 1 } });

    expect(rows[0]).toEqual({ rating: 5, count: 3, share: 75 });
    expect(rows[3]).toEqual({ rating: 2, count: 0, share: 0 });
    expect(rows[4]).toEqual({ rating: 1, count: 1, share: 25 });
  });

  it('keeps only ratings with a comment', () => {
    const rows = commentRows([
      {
        id: 1,
        rating: 5,
        feedback_message: 'Great',
        contact: { name: 'Ava' },
        created_at: 1,
        conversation_id: 7,
      },
      { id: 2, rating: 4, feedback_message: null },
    ]);

    expect(rows).toEqual([
      {
        id: 1,
        rating: 5,
        comment: 'Great',
        name: 'Ava',
        at: 1,
        conversationId: 7,
      },
    ]);
  });
});

describe('chartScale', () => {
  it('rounds the top up and keeps whole gridlines', () => {
    expect(chartScale(15)).toEqual({ top: 20, ticks: [20, 10, 0] });
    expect(chartScale(5)).toEqual({ top: 6, ticks: [6, 3, 0] });
    expect(chartScale(300)).toEqual({ top: 400, ticks: [400, 200, 0] });
    expect(chartScale(0)).toEqual({ top: 2, ticks: [2, 1, 0] });
  });
});

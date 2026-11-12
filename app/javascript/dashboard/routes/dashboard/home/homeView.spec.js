import {
  METRICS,
  dayLabels,
  metricChange,
  metricValue,
  needItems,
  statusPill,
} from './homeView';

const t = (key, params = {}) =>
  Object.keys(params).length ? `${key} ${JSON.stringify(params)}` : key;
const config = key => METRICS.find(metric => metric.key === key);

describe('metricChange', () => {
  it('shows a percent rise as good', () => {
    const change = metricChange(
      config('ai_conversations'),
      { value: 186, previous: 166 },
      t
    );

    expect(change).toEqual({
      text: 'HOME.V2.CHANGE.UP {"amount":"HOME.V2.CHANGE.PERCENT {\\"amount\\":12}"}',
      tone: 'good',
    });
  });

  it('treats fewer handoffs as good', () => {
    const change = metricChange(
      config('handed'),
      { value: 31, previous: 34 },
      t
    );

    expect(change.text).toBe('HOME.V2.CHANGE.DOWN {"amount":"3"}');
    expect(change.tone).toBe('good');
  });

  it('shows a lower rating as bad, to one decimal', () => {
    const change = metricChange(
      config('rating'),
      { value: 4.3, previous: 4.5 },
      t
    );

    expect(change).toEqual({
      text: 'HOME.V2.CHANGE.DOWN {"amount":"0.2"}',
      tone: 'bad',
    });
  });

  it('says nothing without an earlier number to compare with', () => {
    const empty = { text: '', tone: 'neutral' };

    expect(
      metricChange(config('ai_conversations'), { value: 4, previous: 0 }, 7, t)
    ).toEqual(empty);
    expect(
      metricChange(config('rating'), { value: 4, previous: null }, t)
    ).toEqual(empty);
  });

  it('says when nothing changed, but not when both periods are empty', () => {
    expect(
      metricChange(config('resolved'), { value: 70, previous: 70 }, t).text
    ).toBe('HOME.V2.CHANGE.SAME');
    expect(
      metricChange(config('handed'), { value: 0, previous: 0 }, t).text
    ).toBe('');
  });
});

describe('metricValue', () => {
  it('adds the unit and shows a dash for no value', () => {
    expect(metricValue(config('resolved'), 71)).toBe('71%');
    expect(metricValue(config('rating'), null)).toBe('–');
    expect(metricValue(config('handed'), 0)).toBe(0);
  });
});

describe('dayLabels', () => {
  const days = [
    { date: '2026-11-09', ai: 3, team: 1 },
    { date: '2026-11-10', ai: 2, team: 0 },
  ];

  it('uses weekday names for a week and day numbers for a month', () => {
    expect(dayLabels(days, 7, 'en').map(day => day.label)).toEqual([
      'Mon',
      'Tue',
    ]);
    expect(dayLabels(days, 30, 'en')).toEqual([
      { label: '9', ai: 3, team: 1 },
      { label: '10', ai: 2, team: 0 },
    ]);
  });
});

describe('statusPill', () => {
  it('maps the agent status to the kit pill', () => {
    expect(statusPill('limit_reached', t)).toEqual({
      status: 'limit',
      label: 'HOME.V2.STATUS_PILL.LIMIT',
    });
    expect(statusPill('needs_attention', t).status).toBe('attention');
  });
});

describe('needItems', () => {
  it('names each item and links its one button', () => {
    const items = needItems(
      [
        {
          key: 'handoff',
          id: 12,
          name: null,
          inbox: 'Website',
          at: 1794500000,
        },
        {
          key: 'gap',
          id: 4,
          assistant_id: 2,
          question: 'Do you ship to Spain?',
          count: 6,
        },
        {
          key: 'failed_action',
          kind: 'connection',
          id: 3,
          name: 'Shop',
          at: 1794500000,
        },
        { key: 'failed_sync', assistant_id: 2, name: 'Returns', at: null },
        { key: 'channel', id: 9, name: 'Support mail' },
      ],
      t
    );

    expect(items.map(item => [item.key, item.to])).toEqual([
      [
        'handoff',
        { name: 'inbox_conversation', params: { conversation_id: 12 } },
      ],
      [
        'gap',
        {
          name: 'captain_assistants_faq_suggestions',
          params: { assistantId: 2 },
        },
      ],
      [
        'failed_action',
        {
          name: 'captain_assistants_index',
          params: { navigationPath: 'captain_tools_connections' },
        },
      ],
      [
        'failed_sync',
        {
          name: 'captain_assistants_documents_index',
          params: { assistantId: 2 },
        },
      ],
      ['channel', { name: 'settings_inbox_show', params: { inboxId: 9 } }],
    ]);
    expect(items[0].title).toBe(
      'HOME.V2.NEEDS.HANDOFF {"name":"HOME.V2.NEEDS.SOMEONE"}'
    );
    expect(items[3].hint).toBe('');
  });
});

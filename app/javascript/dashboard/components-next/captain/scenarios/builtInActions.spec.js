import {
  buildToolReference,
  parseToolReference,
  groupTools,
  actionChipTitle,
  formatDelay,
} from './builtInActions';

const t = (key, named = {}) =>
  `${key.split('.').pop()}(${Object.values(named).join(',')})`;

describe('builtInActions', () => {
  it('builds and parses references with fixed parameters', () => {
    const reference = buildToolReference('schedule_follow_up', {
      after: '60',
      kind: 'message',
      instructions: 'Ask if it helped?',
      template: '',
    });

    expect(reference).toBe(
      'schedule_follow_up?after=60&kind=message&instructions=Ask+if+it+helped%3F'
    );
    expect(parseToolReference(reference)).toEqual({
      id: 'schedule_follow_up',
      params: {
        after: '60',
        kind: 'message',
        instructions: 'Ask if it helped?',
      },
    });
    expect(buildToolReference('handoff')).toBe('handoff');
  });

  it('groups built-in, custom and MCP tools with one label per group', () => {
    const grouped = groupTools(
      [
        { id: 'custom_quote', custom: true },
        { id: 'faq_lookup' },
        { id: 'crm_lookup', mcp: true },
        { id: 'assign_team', built_in_action: true },
      ],
      group => group
    );

    expect(grouped.map(tool => tool.id)).toEqual([
      'faq_lookup',
      'assign_team',
      'custom_quote',
      'crm_lookup',
    ]);
    expect(grouped.map(tool => tool.groupLabel)).toEqual([
      'BUILT_IN',
      undefined,
      'CUSTOM',
      'MCP',
    ]);
  });

  it('names the fixed value on the chip', () => {
    const lookups = {
      attributes: [
        {
          attribute_key: 'company_size',
          attribute_display_name: 'Company size',
        },
      ],
      teams: [{ id: 3, name: 'Sales' }],
      templates: { demo: { name: 'New demo request' } },
    };

    expect(
      actionChipTitle(
        'update_contact_attribute',
        { key: 'company_size' },
        lookups,
        t
      )
    ).toBe('SAVE(Company size)');
    expect(actionChipTitle('assign_team', { team_id: '3' }, lookups, t)).toBe(
      'ASSIGN(Sales)'
    );
    expect(
      actionChipTitle(
        'assign_agent',
        { agent_id: 'round_robin', team_id: '3' },
        lookups,
        t
      )
    ).toBe('ASSIGN_NEXT_IN(Sales)');
    expect(
      actionChipTitle('email_team', { template: 'demo' }, lookups, t)
    ).toBe('EMAIL_TEAM(New demo request)');
  });

  it('formats delays in the largest whole unit', () => {
    expect([15, 120, 2880].map(minutes => formatDelay(minutes, t))).toEqual([
      'MINUTES(15)',
      'HOURS(2)',
      'DAYS(2)',
    ]);
  });
});

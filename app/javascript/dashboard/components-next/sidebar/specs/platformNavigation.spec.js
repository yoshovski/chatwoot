import {
  groupPlatformNavigation,
  activeNavigationLeaf,
  navigationLeaves,
  moduleForArea,
} from '../platformNavigation';

const route = (name, params = {}) => ({ name, params });

describe('platform navigation', () => {
  it('keeps pages outside the menu, like creating a first portal, in their area', () => {
    const conversations = {
      name: 'Conversation',
      children: [{ name: 'All', to: route('home') }],
    };
    const helpCenter = {
      name: 'Portals',
      children: [{ name: 'Articles', to: route('portals_index') }],
    };
    const paths = {
      home: '/app/accounts/4/dashboard',
      portals_index: '/app/accounts/4/portals/portals_articles_index',
    };
    const match = moduleForArea(
      [conversations, helpCenter],
      { name: 'portals_new', path: '/app/accounts/4/portals/new' },
      to => paths[to.name]
    );
    expect(match).toBe(helpCenter);
  });

  it('keeps existing inbox, company and billing destinations in their new areas', () => {
    const items = [
      { name: 'Inbox', to: route('notifications') },
      {
        name: 'Conversation',
        children: [{ name: 'All', to: route('conversations') }],
      },
      {
        name: 'Contacts',
        children: [{ name: 'Contacts list', to: route('contacts') }],
      },
      {
        name: 'Companies',
        children: [{ name: 'Companies list', to: route('companies') }],
      },
      { name: 'Billing', to: route('billing') },
      {
        name: 'Settings',
        children: [{ name: 'Settings Account Settings', to: route('general') }],
      },
    ];
    const grouped = groupPlatformNavigation(items, key => key);
    expect(grouped.map(item => item.name)).toEqual([
      'Conversation',
      'Contacts',
      'Settings',
    ]);
    expect(navigationLeaves(grouped[0]).map(item => item.to.name)).toEqual([
      'notifications',
      'conversations',
    ]);
    expect(navigationLeaves(grouped[1]).map(item => item.to.name)).toEqual([
      'contacts',
      'companies',
    ]);
    expect(navigationLeaves(grouped[2]).map(item => item.to.name)).toContain(
      'billing'
    );
    expect(items).toHaveLength(6);
  });

  it('selects an agent behavior page through the last-active-agent redirect', () => {
    const instructions = {
      name: 'Instructions',
      to: route('captain_index', {
        accountId: 4,
        navigationPath: 'guidelines',
      }),
    };
    const target = {
      name: 'guidelines',
      path: '/accounts/4/captain/7/settings/guidelines',
      params: { accountId: '4', assistantId: '7' },
    };
    const match = activeNavigationLeaf(
      [{ children: [instructions] }],
      target,
      () => '/accounts/4/captain/guidelines'
    );
    expect(match).toBe(instructions);
  });

  it('matches a contact detail path to its directory while preferring an exact segment', () => {
    const all = { name: 'All', to: route('contacts') };
    const segment = { name: 'VIP', to: route('segment', { segmentId: 5 }) };
    const resolve = to =>
      to.name === 'contacts' ? '/contacts' : '/contacts/segments/5';
    const match = activeNavigationLeaf(
      [all, segment],
      {
        name: 'segment_detail',
        path: '/contacts/segments/5/12',
        params: { segmentId: '5' },
      },
      resolve
    );
    expect(match).toBe(segment);
  });
});

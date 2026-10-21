export const navigationLeaves = item =>
  item.children ? item.children.flatMap(navigationLeaves) : [item];

export const groupPlatformNavigation = (items, t) => {
  const byName = Object.fromEntries(items.map(item => [item.name, item]));
  return items
    .filter(item => !['Inbox', 'Companies', 'Billing'].includes(item.name))
    .map(item => {
      if (item.name === 'Conversation') {
        return { ...item, children: [byName.Inbox, ...item.children] };
      }
      if (item.name === 'Contacts') {
        return {
          ...item,
          label: t('PLATFORM_NAV.CUSTOMERS'),
          children: [
            ...item.children.slice(0, 2),
            ...byName.Companies.children,
            ...item.children.slice(2),
          ],
        };
      }
      if (item.name === 'Settings') {
        const settings = [
          ...item.children,
          { ...byName.Billing, icon: 'i-lucide-credit-card' },
        ];
        const sections = [
          [
            'Workspace',
            'PLATFORM_NAV.WORKSPACE',
            'i-lucide-building-2',
            [
              'Settings Account Settings',
              'Settings Agents',
              'Settings Teams',
              'Settings Custom Roles',
              'Settings Security',
            ],
          ],
          [
            'Services',
            'PLATFORM_NAV.SERVICES',
            'i-lucide-plug',
            [
              'Settings Inboxes',
              'Settings Templates',
              'Settings Integrations',
              'Settings Agent Bots',
            ],
          ],
          [
            'Workflows',
            'PLATFORM_NAV.WORKFLOWS',
            'i-lucide-workflow',
            [
              'Settings Automation',
              'Settings Agent Assignment',
              'Settings Macros',
              'Settings Canned Responses',
              'Settings Sla',
              'Conversation Workflow',
            ],
          ],
        ];
        const assigned = new Set(sections.flatMap(section => section[3]));
        return {
          ...item,
          children: [
            ...sections.map(([name, label, icon, names]) => ({
              name,
              label: t(label),
              icon,
              children: settings.filter(child => names.includes(child.name)),
            })),
            {
              name: 'Administration',
              label: t('PLATFORM_NAV.ADMINISTRATION'),
              icon: 'i-lucide-database',
              children: settings.filter(child => !assigned.has(child.name)),
            },
          ],
        };
      }
      return item;
    });
};

// Route names cover redirects such as Captain's last-active-agent entry point.
// Path prefixes cover detail pages whose route names differ from their index.
export const navigationMatchScore = (item, route, resolvePath) => {
  if (!item.to) return 0;
  const targetName = item.to.params?.navigationPath || item.to.name;
  if (targetName === route.name || item.activeOn?.includes(route.name)) {
    const params = Object.entries(item.to.params || {}).filter(
      ([key]) => key !== 'navigationPath'
    );
    const exact = params.every(
      ([key, value]) => String(route.params[key]) === String(value)
    );
    return exact ? 10000 + params.length : 1000;
  }
  const path = resolvePath(item.to);
  if (path === route.path) return 20000 + path.length;
  return path !== '/' && route.path.startsWith(`${path}/`) ? path.length : 0;
};

export const activeNavigationLeaf = (items, route, resolvePath) =>
  items
    .flatMap(navigationLeaves)
    .map(item => ({
      item,
      score: navigationMatchScore(item, route, resolvePath),
    }))
    .filter(match => match.score > 0)
    .sort((a, b) => b.score - a.score)[0]?.item;

export const navigationLeaves = item =>
  item.children ? item.children.flatMap(navigationLeaves) : [item];

export const groupPlatformNavigation = (items, t) => {
  const byName = Object.fromEntries(items.map(item => [item.name, item]));
  return items
    .filter(item => !['Companies', 'Billing', 'Usage'].includes(item.name))
    .map(item => {
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
          ...(byName.Billing
            ? [{ ...byName.Billing, icon: 'i-lucide-credit-card' }]
            : []),
          ...(byName.Usage
            ? [{ ...byName.Usage, icon: 'i-lucide-chart-no-axes-column' }]
            : []),
        ];
        const bySettingsName = Object.fromEntries(
          settings.map(child => [child.name, child])
        );
        const sections = [
          [
            'Services',
            'PLATFORM_NAV.SERVICES',
            'i-lucide-plug',
            [
              'Settings Inboxes',
              'Settings Integrations',
              'Settings Templates',
              'Settings Agent Bots',
            ],
          ],
          [
            'Workflows',
            'PLATFORM_NAV.WORKFLOWS',
            'i-lucide-workflow',
            [
              'Settings Canned Responses',
              'Settings Macros',
              'Settings Automation',
              'Settings Labels',
              'Settings Custom Attributes',
              'Settings Agent Assignment',
              'Conversation Workflow',
              'Settings Sla',
            ],
          ],
          [
            'Workspace',
            'PLATFORM_NAV.WORKSPACE',
            'i-lucide-building-2',
            ['Settings Agents', 'Settings Teams', 'Settings Custom Roles'],
          ],
          [
            'Administration',
            'PLATFORM_NAV.ADMINISTRATION',
            'i-lucide-briefcase',
            [
              'Billing',
              'Usage',
              'Settings Account Settings',
              'Settings Security',
              'Settings Audit Logs',
              'Settings Data',
            ],
          ],
        ];
        const assigned = new Set(sections.flatMap(section => section[3]));
        return {
          ...item,
          children: sections.map(([name, label, icon, names]) => {
            const groupItems = names
              .map(leafName => bySettingsName[leafName])
              .filter(Boolean);
            if (name === 'Administration') {
              groupItems.push(
                ...settings.filter(child => !assigned.has(child.name))
              );
            }
            return {
              name,
              label: t(label),
              icon,
              children: groupItems,
            };
          }),
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

const areaPath = path => path.split('/').slice(0, 5).join('/');

// Pages outside the menu, such as creating the first Help Center portal, still belong to the
// area whose destinations share their /app/accounts/:accountId/<area> prefix.
export const moduleForArea = (modules, route, resolvePath) => {
  const area = areaPath(route.path);
  return modules.find(item =>
    navigationLeaves(item).some(leaf => areaPath(resolvePath(leaf.to)) === area)
  );
};

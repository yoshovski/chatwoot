export const navigationLeaves = item =>
  item.children ? item.children.flatMap(navigationLeaves) : [item];

export const groupPlatformNavigation = (items, t) => {
  const byName = Object.fromEntries(items.map(item => [item.name, item]));
  return items
    .filter(item => item.name !== 'Companies')
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

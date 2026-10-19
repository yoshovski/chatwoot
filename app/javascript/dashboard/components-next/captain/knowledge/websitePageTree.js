export const buildWebsiteTree = (pages, search = '') => {
  const roots = new Map();
  const query = search.trim().toLowerCase();
  pages.forEach(page => {
    if (!`${page.url} ${page.title || ''}`.toLowerCase().includes(query))
      return;
    const url = new URL(page.url);
    const segments = [url.host, ...url.pathname.split('/').filter(Boolean)];
    if (url.search) segments.push(url.search);
    let siblings = roots;
    let node;
    segments.forEach((label, index) => {
      const key = segments.slice(0, index + 1).join('/');
      if (!siblings.has(key)) {
        siblings.set(key, { key, label, children: new Map(), pages: [] });
      }
      node = siblings.get(key);
      if (!page.blocked_reason) node.pages.push(page.url);
      siblings = node.children;
    });
    node.page = page;
  });
  const serialize = nodes =>
    [...nodes.values()]
      .sort((a, b) => a.label.localeCompare(b.label))
      .map(node => ({ ...node, children: serialize(node.children) }));
  return serialize(roots);
};

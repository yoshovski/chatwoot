export const BUCKETS = ['recommended', 'maybe', 'excluded'];
// The picker shows two tabs: recommended pages, and everything else.
export const TABS = ['recommended', 'other'];

const inTab = (page, tab) =>
  tab === 'all' ||
  (tab === 'other' ? page.bucket !== 'recommended' : page.bucket === tab);

const hostOf = url => new URL(url).host.replace(/^www\./, '');

const pageLabel = page => {
  if (page.title) return page.title;
  const { pathname, search } = new URL(page.url);
  return `${pathname}${search}`;
};

const matches = (page, query) =>
  !query || `${page.url} ${page.title || ''}`.toLowerCase().includes(query);

const byCountThenLabel = (a, b) =>
  b.pages.length - a.pages.length || a.label.localeCompare(b.label);

// Groups pages as host → section → page. Sections come from discovery
// (host + first path segment, or a help-centre section name).
export const buildWebsiteTree = (
  pages,
  { search = '', bucket = 'all', startHost = '' } = {}
) => {
  const query = search.trim().toLowerCase();
  const hosts = new Map();
  pages.forEach(page => {
    if (!inTab(page, bucket)) return;
    if (!matches(page, query)) return;

    const host = hostOf(page.url);
    const sectionKey = page.section || host;
    if (!hosts.has(host)) {
      hosts.set(host, { key: host, label: host, sections: new Map() });
    }
    const { sections } = hosts.get(host);
    if (!sections.has(sectionKey)) {
      sections.set(sectionKey, {
        key: sectionKey,
        label: sectionKey.slice(host.length + 1),
        section: sectionKey,
        children: [],
      });
    }
    sections.get(sectionKey).children.push({
      key: page.url,
      label: pageLabel(page),
      page,
      children: [],
      pages: page.blocked_reason ? [] : [page.url],
    });
  });

  const hostNodes = [...hosts.values()].map(({ key, label, sections }) => {
    const children = [...sections.values()]
      .map(section => ({
        ...section,
        children: section.children.sort((a, b) =>
          a.label.localeCompare(b.label)
        ),
        pages: section.children.flatMap(child => child.pages),
      }))
      .sort(byCountThenLabel);
    return {
      key,
      label,
      children,
      pages: children.flatMap(child => child.pages),
    };
  });
  return hostNodes.sort(
    (a, b) =>
      (b.key === startHost) - (a.key === startHost) || byCountThenLabel(a, b)
  );
};

export const countByBucket = pages =>
  pages.reduce(
    (counts, page) => {
      counts.all += 1;
      if (page.bucket) counts[page.bucket] += 1;
      return counts;
    },
    { all: 0, recommended: 0, maybe: 0, excluded: 0 }
  );

export const countByTab = pages => {
  const counts = countByBucket(pages);
  return {
    recommended: counts.recommended,
    other: counts.all - counts.recommended,
  };
};

export const recommendedUrls = pages =>
  pages
    .filter(page => page.bucket === 'recommended' && !page.blocked_reason)
    .map(page => page.url);

import {
  buildWebsiteTree,
  countByBucket,
  recommendedUrls,
} from './websitePageTree';

const pages = [
  {
    url: 'https://www.example.com/pricing',
    title: 'Pricing',
    section: 'example.com/pricing',
    bucket: 'recommended',
  },
  {
    url: 'https://www.example.com',
    title: 'Home',
    section: 'example.com',
    bucket: 'recommended',
  },
  {
    url: 'https://support.example.com/hc/en-us/articles/1-Billing',
    title: 'Billing',
    section: 'support.example.com/Payments',
    bucket: 'recommended',
  },
  {
    url: 'https://support.example.com/hc/en-us/articles/2-Refunds',
    title: 'Refunds',
    section: 'support.example.com/Payments',
    bucket: 'recommended',
  },
  {
    url: 'https://blog.example.com/2024/launch',
    title: 'Launch',
    section: 'blog.example.com/2024',
    bucket: 'maybe',
  },
  {
    url: 'https://api.example.com/v1',
    section: 'api.example.com/v1',
    bucket: 'excluded',
    reason: 'technical_host',
  },
  {
    url: 'https://www.example.com/private',
    section: 'example.com/private',
    bucket: 'excluded',
    blocked_reason: 'robots_disallowed',
  },
];

describe('buildWebsiteTree', () => {
  it('groups pages by host and section, start host first', () => {
    const tree = buildWebsiteTree(pages, {
      bucket: 'recommended',
      startHost: 'example.com',
    });

    expect(tree.map(node => node.key)).toEqual([
      'example.com',
      'support.example.com',
    ]);
    const support = tree[1];
    expect(support.children).toHaveLength(1);
    expect(support.children[0]).toMatchObject({
      label: 'Payments',
      section: 'support.example.com/Payments',
    });
    expect(support.children[0].children.map(node => node.label)).toEqual([
      'Billing',
      'Refunds',
    ]);
    expect(support.pages).toHaveLength(2);
  });

  it('labels top-level pages with an empty section name', () => {
    const [home] = buildWebsiteTree(pages, {
      bucket: 'recommended',
      startHost: 'example.com',
    });
    expect(home.children.map(node => node.label)).toContain('');
  });

  it('keeps blocked pages visible but unselectable', () => {
    const tree = buildWebsiteTree(pages, { bucket: 'excluded' });
    const blocked = tree.find(node => node.key === 'example.com');

    expect(blocked.pages).toEqual([]);
    expect(blocked.children[0].children[0].page.blocked_reason).toBe(
      'robots_disallowed'
    );
  });

  it('filters by search text across url and title', () => {
    const tree = buildWebsiteTree(pages, { search: 'refund' });
    expect(tree.flatMap(node => node.pages)).toEqual([
      'https://support.example.com/hc/en-us/articles/2-Refunds',
    ]);
  });
});

describe('bucket helpers', () => {
  it('counts pages per bucket', () => {
    expect(countByBucket(pages)).toEqual({
      all: 7,
      recommended: 4,
      maybe: 1,
      excluded: 2,
    });
  });

  it('lists selectable recommended urls', () => {
    expect(recommendedUrls(pages)).toHaveLength(4);
  });
});

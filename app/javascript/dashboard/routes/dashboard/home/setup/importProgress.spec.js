import { importProgress, pagesToImport } from './importProgress';

const page = (url, extra = {}) => ({ url, bucket: 'recommended', ...extra });

describe('importProgress', () => {
  it('is idle without a website', () => {
    expect(importProgress(null)).toEqual({ phase: 'idle' });
  });

  it('is finding pages while discovery or its checks run', () => {
    expect(
      importProgress({ status: 'discovering', pages: [page('a')] })
    ).toEqual({ phase: 'finding', found: 1 });
    expect(
      importProgress({
        status: 'ready',
        pages: [],
        discovery_stats: { classification: 'pending' },
      }).phase
    ).toBe('finding');
  });

  it('picks the recommended pages once discovery settles', () => {
    const progress = importProgress({
      status: 'ready',
      pages: [page('a'), page('b', { bucket: 'maybe' }), page('c')],
    });

    expect(progress).toMatchObject({ phase: 'select', urls: ['a', 'c'] });
  });

  it('has nothing to import when no page is recommended', () => {
    expect(
      importProgress({
        status: 'ready',
        pages: [page('a', { bucket: 'maybe' })],
      }).phase
    ).toBe('empty');
  });

  it('counts read and failed pages of the selection', () => {
    const source = {
      status: 'ready',
      selected_urls: ['a', 'b', 'c'],
      pages: [
        page('a', { knowledge_state: 'searchable' }),
        page('b', { sync_status: 'failed' }),
        page('c', { sync_status: 'syncing' }),
      ],
    };

    expect(importProgress(source)).toEqual({
      phase: 'reading',
      found: 3,
      total: 3,
      ready: 1,
      failed: 1,
    });
    source.pages[2].sync_status = 'synced';
    expect(importProgress(source).phase).toBe('done');
  });

  it('fails when discovery failed or stalled', () => {
    expect(importProgress({ status: 'failed' }).phase).toBe('failed');
    expect(
      importProgress({ status: 'discovering', recoverable: true, pages: [] })
        .phase
    ).toBe('failed');
  });
});

describe('pagesToImport', () => {
  it('stays within the document limit', () => {
    const progress = { urls: ['a', 'b', 'c'] };

    expect(pagesToImport(progress, 2)).toEqual(['a', 'b']);
    expect(pagesToImport(progress, 0)).toEqual([]);
    expect(pagesToImport(progress, undefined)).toEqual(['a', 'b', 'c']);
  });
});

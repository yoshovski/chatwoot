import { recommendedUrls } from 'dashboard/components-next/captain/knowledge/websitePageTree';

const READY_STATES = ['searchable', 'synced'];
const FAILED_STATES = ['failed', 'not_searchable'];

const pageState = page => page.knowledge_state || page.sync_status;

// Where a website import stands, in the words of the website step: finding pages, nothing to import, reading the
// chosen pages, done or failed. Uses the same discovery states as the page picker (WebsiteSourceSelection).
export const importProgress = source => {
  if (!source) return { phase: 'idle' };
  if (source.status === 'failed') return { phase: 'failed' };

  const pages = source.pages || [];
  const stats = source.discovery_stats || {};
  const selected = new Set(source.selected_urls || []);
  const found = pages.length;

  if (selected.size) {
    const chosen = pages.filter(page => selected.has(page.url));
    const ready = chosen.filter(page =>
      READY_STATES.includes(pageState(page))
    ).length;
    const failed = chosen.filter(page =>
      FAILED_STATES.includes(pageState(page))
    ).length;
    const total = selected.size;
    const phase = ready + failed >= total ? 'done' : 'reading';
    return { phase, found, total, ready, failed };
  }

  const discovering =
    ['pending', 'discovering'].includes(source.status) && !source.recoverable;
  const checking = [stats.classification, stats.verification].includes(
    'pending'
  );
  if (discovering || checking || stats.continue)
    return { phase: 'finding', found };
  if (source.recoverable) return { phase: 'failed' };

  const urls = recommendedUrls(pages);
  return urls.length
    ? { phase: 'select', found, urls }
    : { phase: 'empty', found };
};

// The pages the guided setup imports: the recommended ones, within the account's document limit.
export const pagesToImport = (progress, documentsAvailable) => {
  const urls = progress.urls || [];
  return documentsAvailable === undefined || documentsAvailable === null
    ? urls
    : urls.slice(0, Math.max(documentsAvailable, 0));
};

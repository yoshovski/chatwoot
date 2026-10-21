export const hostOf = url => {
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return '';
  }
};

// The website source a host's pages were discovered from: the source's own
// host, a parent or child domain of it, or any host among its selected pages.
export const sourceForHost = (sources, host) =>
  sources.find(source => {
    const sourceHost = hostOf(source.url);
    if (!sourceHost) return false;
    if (sourceHost === host) return true;
    if (host.endsWith(`.${sourceHost}`) || sourceHost.endsWith(`.${host}`)) {
      return true;
    }
    return (source.selected_urls || []).some(url => hostOf(url) === host);
  }) || null;

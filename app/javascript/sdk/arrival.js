const UTM_KEYS = ['utm_source', 'utm_medium', 'utm_campaign'];
export const UTM_LIMIT = 100;

// How the visitor reached this page: the referrer host (never its path or query) and the UTM values, each cut to
// UTM_LIMIT characters. A referrer on the same site is internal navigation, not an arrival. Null when there is none.
export const readArrival = ({
  referrer = document.referrer,
  search = window.location.search,
  host = window.location.host,
} = {}) => {
  const arrival = {};
  try {
    const referrerHost = referrer ? new URL(referrer).host : '';
    if (referrerHost && referrerHost !== host) {
      arrival.referrer_host = referrerHost;
    }
  } catch (error) {
    // An unparsable referrer is no arrival source.
  }
  const params = new URLSearchParams(search);
  UTM_KEYS.forEach(key => {
    const value = (params.get(key) || '').trim().slice(0, UTM_LIMIT);
    if (value) arrival[key] = value;
  });
  return Object.keys(arrival).length ? arrival : null;
};

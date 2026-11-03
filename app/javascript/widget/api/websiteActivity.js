import { API } from 'widget/helpers/axios';
import { buildSearchParamsWithLocale } from '../helpers/urlParamsHelper';

const ARRIVAL_STORAGE_KEY = 'cw_visit_arrival';
let arrival = null;

// The SDK reads the arrival once per page load; a page reached by internal navigation has none, so the landing's
// arrival is kept for the tab (sessionStorage) until a page with its own arrival replaces it.
export const setArrival = value => {
  if (!value) return;
  arrival = value;
  try {
    window.sessionStorage.setItem(ARRIVAL_STORAGE_KEY, JSON.stringify(value));
  } catch (error) {
    // Storage can be blocked; the arrival then lives for this page only.
  }
};

const storedArrival = () => {
  if (arrival) return arrival;
  try {
    return JSON.parse(window.sessionStorage.getItem(ARRIVAL_STORAGE_KEY));
  } catch (error) {
    return null;
  }
};

const browserTimezone = () => {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || undefined;
  } catch (error) {
    return undefined;
  }
};

export const visitParams = () => ({
  ...(storedArrival() || {}),
  timezone: browserTimezone(),
});

export const recordWebsiteActivity = () => {
  if (!window.referrerURL) return Promise.resolve();

  const pageURL = new URL(window.referrerURL);
  pageURL.username = '';
  pageURL.password = '';
  pageURL.search = '';
  pageURL.hash = '';
  const search = buildSearchParamsWithLocale(window.location.search);
  return API.post(`/api/v1/widget/website_activity${search}`, {
    page: { url: pageURL.toString(), title: window.referrerPageTitle || '' },
    visit: visitParams(),
  }).catch(() => {
    // Navigation metadata must never interrupt the visitor's chat.
  });
};

// Activity is recorded only after the visitor's first message, so the arrival and time zone go out once the first
// message of this page load was sent (the message itself records the page, without them).
let visitSent = false;
export const recordVisitAfterFirstMessage = () => {
  if (visitSent) return Promise.resolve();
  visitSent = true;
  return recordWebsiteActivity();
};

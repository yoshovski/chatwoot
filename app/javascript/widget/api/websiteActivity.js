import { API } from 'widget/helpers/axios';
import { buildSearchParamsWithLocale } from '../helpers/urlParamsHelper';

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
  }).catch(() => {
    // Navigation metadata must never interrupt the visitor's chat.
  });
};

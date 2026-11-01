import axios from 'axios';
import { APP_BASE_URL } from 'widget/helpers/constants';
import { isPreviewMode } from 'widget/helpers/previewMode';

export const API = axios.create({
  baseURL: APP_BASE_URL,
  withCredentials: false,
});

// The settings preview has no visitor session: no request may create a contact, conversation or visit.
API.interceptors.request.use(config =>
  isPreviewMode()
    ? Promise.reject(new Error('The widget preview makes no API calls'))
    : config
);

export const setHeader = (value, key = 'X-Auth-Token') => {
  API.defaults.headers.common[key] = value;
};

export const removeHeader = key => {
  delete API.defaults.headers.common[key];
};

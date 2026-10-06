/* global axios */
import ApiClient from '../ApiClient';

// Viewer's UTC offset in hours, matching the reports API convention so the
// backend can anchor calendar ranges to the viewer's day.
const getTimezoneOffset = () => -new Date().getTimezoneOffset() / 60;

class CaptainAssistant extends ApiClient {
  constructor() {
    super('captain/assistants', { accountScoped: true });
  }

  get({ page = 1, searchKey } = {}) {
    return axios.get(this.url, {
      params: {
        page,
        searchKey,
      },
    });
  }

  update(id, data) {
    if (data instanceof FormData) {
      return axios.patch(`${this.url}/${id}`, data);
    }

    if (data?.avatar instanceof File || data?.avatar instanceof Blob) {
      const formData = new FormData();
      Object.keys(data).forEach(key => {
        if (key === 'config') {
          Object.keys(data.config || {}).forEach(configKey => {
            formData.append(
              `assistant[config][${configKey}]`,
              data.config[configKey]
            );
          });
        } else if (key === 'avatar') {
          formData.append('assistant[avatar]', data.avatar);
        } else if (Array.isArray(data[key])) {
          data[key].forEach(item => {
            formData.append(`assistant[${key}][]`, item);
          });
        } else if (data[key] !== undefined && data[key] !== null) {
          formData.append(`assistant[${key}]`, data[key]);
        }
      });
      return axios.patch(`${this.url}/${id}`, formData);
    }

    return super.update(id, data);
  }

  deleteAvatar(assistantId) {
    return axios.delete(`${this.url}/${assistantId}/avatar`);
  }

  playground({
    assistantId,
    messageContent,
    messageHistory,
    playgroundConfig,
  }) {
    const payload = {
      message_content: messageContent,
      message_history: messageHistory,
    };
    if (playgroundConfig) payload.playground_config = playgroundConfig;

    return axios.post(`${this.url}/${assistantId}/playground`, payload);
  }

  getMetrics({ assistantId, range, signal }) {
    const requestConfig = {
      params: { range, timezone_offset: getTimezoneOffset() },
    };
    if (signal) requestConfig.signal = signal;

    return axios.get(`${this.url}/${assistantId}/metrics`, requestConfig);
  }

  getFaqStats({ assistantId, signal }) {
    const requestConfig = {};
    if (signal) requestConfig.signal = signal;

    return axios.get(`${this.url}/${assistantId}/faq_stats`, requestConfig);
  }

  getSummary({ assistantId, range, stats }) {
    return axios.get(`${this.url}/${assistantId}/summary`, {
      params: { range, timezone_offset: getTimezoneOffset(), stats },
    });
  }

  getDrilldown({ assistantId, metric, range, page, signal }) {
    const requestConfig = {
      params: {
        metric,
        range,
        timezone_offset: getTimezoneOffset(),
        page,
      },
    };
    if (signal) requestConfig.signal = signal;

    return axios.get(`${this.url}/${assistantId}/drilldown`, requestConfig);
  }
}

export default new CaptainAssistant();

/* global axios */
import ApiClient from '../ApiClient';

// Viewer's UTC offset in hours, matching the reports API convention so the
// backend can anchor calendar ranges to the viewer's day.
const getTimezoneOffset = () => -new Date().getTimezoneOffset() / 60;

// Captain V2 playground runs happen in a background job; poll until the reply is stored.
const PLAYGROUND_POLL_INTERVAL_MS = 1000;
const PLAYGROUND_MAX_WAIT_MS = 3 * 60 * 1000;

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

  async playground({
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

    const response = await axios.post(
      `${this.url}/${assistantId}/playground`,
      payload
    );
    if (response.status !== 202) return response;

    return this.waitForPlaygroundRun(assistantId, response.data.run_id);
  }

  async waitForPlaygroundRun(assistantId, runId, startedAt = Date.now()) {
    await new Promise(resolve => {
      setTimeout(resolve, PLAYGROUND_POLL_INTERVAL_MS);
    });
    const { data } = await axios.get(
      `${this.url}/${assistantId}/playground_runs/${runId}`
    );
    if (data.status === 'done') return { data: data.response };
    if (
      data.status === 'failed' ||
      Date.now() - startedAt > PLAYGROUND_MAX_WAIT_MS
    ) {
      const error = new Error(data.error || 'Playground run timed out');
      error.response = { data: { error: data.error } };
      throw error;
    }
    return this.waitForPlaygroundRun(assistantId, runId, startedAt);
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

/* global axios */
import ApiClient from '../ApiClient';

class CaptainHome extends ApiClient {
  constructor() {
    super('captain/home', { accountScoped: true });
  }

  // period: 7 or 30 days. timezoneOffset: the viewer's UTC offset in hours, so days follow their calendar.
  get({ signal, period, timezoneOffset } = {}) {
    return axios.get(this.url, {
      signal,
      params: { period, timezone_offset: timezoneOffset },
    });
  }
}

export default new CaptainHome();

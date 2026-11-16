/* global axios */
import ApiClient from '../ApiClient';

class CaptainHome extends ApiClient {
  constructor() {
    super('captain/home', { accountScoped: true });
  }

  // Home uses period (7 or 30 calendar days); Analytics uses range (Overview rolling/calendar windows).
  // timezoneOffset is the viewer's UTC offset in hours.
  get({
    signal,
    period,
    range,
    timezoneOffset,
    startDate,
    endDate,
    timeZone,
  } = {}) {
    return axios.get(this.url, {
      signal,
      params: {
        period,
        range,
        timezone_offset: timezoneOffset,
        start_date: startDate,
        end_date: endDate,
        time_zone: timeZone,
      },
    });
  }

  live(signal) {
    return axios.get(`${this.url}/live`, { signal });
  }
}

export default new CaptainHome();

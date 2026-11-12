/* global axios */
import ApiClient from './ApiClient';

class AccountSubscriptionAPI extends ApiClient {
  constructor() {
    super('account_subscription', { accountScoped: true });
  }

  get({ sync = false } = {}) {
    return axios.get(this.url, { params: { sync } });
  }

  checkout(interval) {
    return axios.post(`${this.url}/checkout`, { interval });
  }

  changeInterval(interval) {
    return axios.post(`${this.url}/change_interval`, { interval });
  }

  payment() {
    return axios.post(`${this.url}/payment`);
  }

  // requestId is one per click: a double submit or a retried request charges once.
  topUp(requestId) {
    return axios.post(`${this.url}/top_up`, { request_id: requestId });
  }

  updateTopUpSettings(settings) {
    return axios.patch(`${this.url}/top_up_settings`, settings);
  }

  portal() {
    return axios.post(`${this.url}/portal`);
  }
}
export default new AccountSubscriptionAPI();

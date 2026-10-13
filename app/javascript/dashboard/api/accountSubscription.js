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

  payment() {
    return axios.post(`${this.url}/payment`);
  }

  portal() {
    return axios.post(`${this.url}/portal`);
  }
}
export default new AccountSubscriptionAPI();

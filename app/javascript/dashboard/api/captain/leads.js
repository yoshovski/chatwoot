/* global axios */
import ApiClient from '../ApiClient';

class LeadsAPI extends ApiClient {
  constructor() {
    super('captain/leads', { accountScoped: true });
  }

  get(params, signal) {
    return axios.get(this.url, { params, signal });
  }

  export(status) {
    return axios.get(`${this.url}/export`, { params: { status } });
  }
}

export default new LeadsAPI();

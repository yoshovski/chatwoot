/* global axios */
import ApiClient from './ApiClient';

class HubspotAPI extends ApiClient {
  constructor() {
    super('hubspot', { accountScoped: true });
  }

  generateAuthorization() {
    return axios.post(`${this.url}/authorization`);
  }
}

export default new HubspotAPI();

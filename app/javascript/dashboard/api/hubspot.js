/* global axios */
import ApiClient from './ApiClient';

class HubspotAPI extends ApiClient {
  constructor() {
    super('hubspot', { accountScoped: true });
  }

  generateAuthorization() {
    return axios.post(`${this.url}/authorization`);
  }

  getProperties() {
    return axios.get(`${this.baseUrl()}/integrations/hubspot/properties`);
  }

  getContact(contactId, { signal } = {}) {
    return axios.get(`${this.baseUrl()}/integrations/hubspot/contact`, {
      params: { contact_id: contactId },
      signal,
    });
  }

  updateSettings(settings) {
    return axios.patch(`${this.baseUrl()}/integrations/hubspot`, { settings });
  }
}

export default new HubspotAPI();

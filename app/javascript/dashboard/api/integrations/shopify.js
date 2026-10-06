/* global axios */

import ApiClient from '../ApiClient';

class ShopifyAPI extends ApiClient {
  constructor() {
    super('integrations/shopify', { accountScoped: true });
  }

  getStatus() {
    return axios.get(this.url);
  }

  requestConnection({ shopDomain }) {
    return axios.post(`${this.url}/request_connection`, {
      shop_domain: shopDomain,
    });
  }

  syncStatus() {
    return axios.post(`${this.url}/sync_status`);
  }

  disconnect() {
    return axios.delete(this.url);
  }

  pauseCatalog() {
    return axios.post(`${this.url}/pause_catalog`);
  }

  resumeCatalog() {
    return axios.post(`${this.url}/resume_catalog`);
  }

  getOrders(contactId) {
    return axios.get(`${this.url}/orders`, {
      params: { contact_id: contactId },
    });
  }
}

export default new ShopifyAPI();

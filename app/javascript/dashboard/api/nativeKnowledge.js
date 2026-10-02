/* global axios */
import ApiClient from './ApiClient';

class NativeKnowledgeAPI extends ApiClient {
  constructor() {
    super('ai_agents/knowledge', { accountScoped: true });
  }

  request(method, path, data, options = {}) {
    return axios({ method, url: `${this.url}${path}`, data, ...options });
  }
}

export default new NativeKnowledgeAPI();

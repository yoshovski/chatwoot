/* global axios */
import ApiClient from '../ApiClient';

class CaptainKnowledgeGaps extends ApiClient {
  constructor() {
    super('captain/knowledge_gaps', { accountScoped: true });
  }

  get({ page = 1, search, assistantId, signal } = {}) {
    return axios.get(this.url, {
      params: { page, search, assistant_id: assistantId },
      signal,
    });
  }

  show(id, { signal } = {}) {
    return axios.get(`${this.url}/${id}`, { signal });
  }

  answer(id, { question, answer }) {
    return axios.post(`${this.url}/${id}/answer`, {
      knowledge_gap: { question, answer },
    });
  }

  dismiss(id) {
    return axios.post(`${this.url}/${id}/dismiss`);
  }
}

export default new CaptainKnowledgeGaps();

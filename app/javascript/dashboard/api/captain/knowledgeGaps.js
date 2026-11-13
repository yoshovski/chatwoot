/* global axios */
import ApiClient from '../ApiClient';

class CaptainKnowledgeGaps extends ApiClient {
  constructor() {
    super('captain/knowledge_gaps', { accountScoped: true });
  }

  answer(id, { question, answer }) {
    return axios.post(`${this.url}/${id}/answer`, {
      knowledge_gap: { question, answer },
    });
  }

  dismiss(id) {
    return axios.post(`${this.url}/${id}/dismiss`);
  }

  // The Unanswered list grouped by topic, busiest topic first.
  topics({ assistantId, search, signal } = {}) {
    return axios.get(`${this.url}/topics`, {
      params: { assistant_id: assistantId, search },
      signal,
    });
  }

  // What customers asked the AI agent to do, one entry per intent.
  actionRequests({ assistantId, signal } = {}) {
    return axios.get(`${this.url}/action_requests`, {
      params: { assistant_id: assistantId },
      signal,
    });
  }

  bulkDismiss(ids) {
    return axios.post(`${this.url}/bulk_dismiss`, { ids });
  }
}

export default new CaptainKnowledgeGaps();

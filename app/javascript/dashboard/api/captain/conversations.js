/* global axios */
import ApiClient from '../ApiClient';

class CaptainConversations extends ApiClient {
  constructor() {
    super('captain/conversations', { accountScoped: true });
  }

  takeOver(conversationId) {
    return axios.post(`${this.url}/${conversationId}/takeover`);
  }

  getScheduledActions(conversationId) {
    return axios.get(`${this.url}/${conversationId}/scheduled_actions`);
  }

  cancelScheduledAction(conversationId, actionId) {
    return axios.delete(
      `${this.url}/${conversationId}/scheduled_actions/${actionId}`
    );
  }
}

export default new CaptainConversations();

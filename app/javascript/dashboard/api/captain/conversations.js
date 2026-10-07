/* global axios */
import ApiClient from '../ApiClient';

class CaptainConversations extends ApiClient {
  constructor() {
    super('captain/conversations', { accountScoped: true });
  }

  takeOver(conversationId) {
    return axios.post(`${this.url}/${conversationId}/takeover`);
  }
}

export default new CaptainConversations();

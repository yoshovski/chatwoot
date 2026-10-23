/* global axios */
import ApiClient from '../ApiClient';

class CaptainMcpServers extends ApiClient {
  constructor() {
    super('captain/mcp_servers', { accountScoped: true });
  }

  create(data = {}) {
    return axios.post(this.url, { mcp_server: data });
  }

  update(id, data = {}) {
    return axios.patch(`${this.url}/${id}`, { mcp_server: data });
  }

  sync(id) {
    return axios.post(`${this.url}/${id}/sync`);
  }
}

export default new CaptainMcpServers();

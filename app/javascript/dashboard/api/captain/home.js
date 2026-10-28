/* global axios */
import ApiClient from '../ApiClient';

class CaptainHome extends ApiClient {
  constructor() {
    super('captain/home', { accountScoped: true });
  }

  get({ signal } = {}) {
    return axios.get(this.url, { signal });
  }
}

export default new CaptainHome();

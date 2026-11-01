/* global axios */
import ApiClient from '../ApiClient';

class CaptainGuidedSetup extends ApiClient {
  constructor() {
    super('captain/guided_setup', { accountScoped: true });
  }

  get({ signal } = {}) {
    return axios.get(this.url, { signal });
  }

  startWebsite(url) {
    return axios.post(`${this.url}/website`, { url });
  }

  goLive() {
    return axios.post(`${this.url}/go_live`);
  }

  checkInstallation(inboxId) {
    return axios.post(
      `${this.url}/check_installation`,
      inboxId ? { inbox_id: inboxId } : {}
    );
  }
}

export default new CaptainGuidedSetup();

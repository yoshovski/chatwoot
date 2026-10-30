import { VOICE_CALL_PROVIDERS } from 'dashboard/helper/inbox';
import TwilioVoiceClient from './twilioVoiceClient';
import TelnyxVoiceClient from './telnyxVoiceClient';

const CLIENTS = {
  [VOICE_CALL_PROVIDERS.TWILIO]: TwilioVoiceClient,
  [VOICE_CALL_PROVIDERS.TELNYX]: TelnyxVoiceClient,
};

// Routes the browser leg of a phone call to the provider's WebRTC client. Both clients share
// one surface (initializeDevice / joinClientCall / setMuted / endClientCall) and emit
// `call:disconnected`, which is re-dispatched here so listeners attach once.
class VoiceClient extends EventTarget {
  constructor() {
    super();
    this.current = TwilioVoiceClient;
    Object.values(CLIENTS).forEach(client =>
      client.addEventListener('call:disconnected', () =>
        this.dispatchEvent(new CustomEvent('call:disconnected'))
      )
    );
  }

  async initializeDevice(inboxId, provider = VOICE_CALL_PROVIDERS.TWILIO) {
    const next = CLIENTS[provider] || TwilioVoiceClient;
    if (next !== this.current) this.current.destroyDevice();
    this.current = next;
    return this.current.initializeDevice(inboxId);
  }

  get hasActiveConnection() {
    return this.current.hasActiveConnection;
  }

  joinClientCall(params) {
    return this.current.joinClientCall(params);
  }

  setMuted(shouldMute) {
    return this.current.setMuted(shouldMute);
  }

  endClientCall() {
    this.current.endClientCall();
  }

  destroyDevice() {
    this.current.destroyDevice();
  }
}

export default new VoiceClient();

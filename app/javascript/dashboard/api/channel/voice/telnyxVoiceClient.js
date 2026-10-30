import { TelnyxRTC } from '@telnyx/webrtc';
import VoiceAPI from './voiceAPIClient';

const createCallDisconnectedEvent = () => new CustomEvent('call:disconnected');

// How long to wait for the server to ring this agent's credential after joinConference.
const INVITE_TIMEOUT_MS = 20000;
const ENDED_STATES = ['hangup', 'destroy', 'purge'];

// Same surface as TwilioVoiceClient. The difference is direction: a Telnyx agent never
// dials out. joinConference makes the backend ring this agent's WebRTC credential over
// SIP, and joinClientCall answers that invite, which drops the agent into the conference.
class TelnyxVoiceClient extends EventTarget {
  constructor() {
    super();
    this.client = null;
    this.activeConnection = null;
    this.pendingInvite = null;
    this.inviteWaiter = null;
    this.initialized = false;
    this.inboxId = null;
    this.audioElement = null;
  }

  async initializeDevice(inboxId) {
    this.destroyDevice();

    const response = await VoiceAPI.getToken(inboxId);
    const { token } = response || {};
    if (!token) throw new Error('Invalid token');

    this.client = new TelnyxRTC({ login_token: token });
    this.client.remoteElement = this.ensureAudioElement();
    this.client.on('telnyx.notification', this.onNotification);

    await new Promise((resolve, reject) => {
      this.client.on('telnyx.ready', resolve);
      this.client.on('telnyx.error', reject);
      this.client.connect();
    });

    this.initialized = true;
    this.inboxId = inboxId;
    return this.client;
  }

  get hasActiveConnection() {
    return !!this.activeConnection;
  }

  setMuted(shouldMute) {
    if (!this.activeConnection) return false;
    if (shouldMute) this.activeConnection.muteAudio();
    else this.activeConnection.unmuteAudio();
    return shouldMute;
  }

  endClientCall() {
    const call = this.activeConnection || this.pendingInvite;
    this.activeConnection = null;
    this.pendingInvite = null;
    this.rejectWaiter(new Error('Call ended'));
    if (call && !ENDED_STATES.includes(call.state)) call.hangup();
  }

  destroyDevice() {
    this.endClientCall();
    if (this.client) {
      this.client.off('telnyx.notification', this.onNotification);
      this.client.disconnect();
    }
    this.client = null;
    this.initialized = false;
    this.inboxId = null;
  }

  async joinClientCall() {
    if (!this.client || !this.initialized) return null;
    if (this.activeConnection) return this.activeConnection;

    const invite = this.pendingInvite || (await this.waitForInvite());
    this.pendingInvite = null;
    await invite.answer();
    this.activeConnection = invite;
    return invite;
  }

  waitForInvite() {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.inviteWaiter = null;
        reject(
          new Error('Timed out waiting for the call to reach this browser')
        );
      }, INVITE_TIMEOUT_MS);
      this.inviteWaiter = {
        resolve: call => {
          clearTimeout(timer);
          resolve(call);
        },
        reject: error => {
          clearTimeout(timer);
          reject(error);
        },
      };
    });
  }

  rejectWaiter(error) {
    const waiter = this.inviteWaiter;
    this.inviteWaiter = null;
    waiter?.reject(error);
  }

  ensureAudioElement() {
    if (!this.audioElement) {
      this.audioElement = document.createElement('audio');
      this.audioElement.autoplay = true;
      this.audioElement.hidden = true;
      document.body.appendChild(this.audioElement);
    }
    return this.audioElement;
  }

  onNotification = notification => {
    const { call } = notification || {};
    if (notification?.type !== 'callUpdate' || !call) return;

    if (call.state === 'ringing' && call.direction === 'inbound') {
      // The invite can land before joinClientCall starts waiting, so park it.
      if (this.inviteWaiter) {
        const waiter = this.inviteWaiter;
        this.inviteWaiter = null;
        waiter.resolve(call);
      } else {
        this.pendingInvite = call;
      }
      return;
    }

    if (
      ENDED_STATES.includes(call.state) &&
      call.id === this.activeConnection?.id
    ) {
      this.activeConnection = null;
      this.dispatchEvent(createCallDisconnectedEvent());
    }
  };
}

export default new TelnyxVoiceClient();

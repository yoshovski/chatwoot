import TelnyxVoiceClient from '../../channel/voice/telnyxVoiceClient';
import VoiceAPI from '../../channel/voice/voiceAPIClient';

const handlers = {};
const rtcInstance = {
  on: vi.fn((event, cb) => {
    handlers[event] = cb;
  }),
  off: vi.fn(),
  connect: vi.fn(() => handlers['telnyx.ready']?.()),
  disconnect: vi.fn(),
};

vi.mock('@telnyx/webrtc', () => ({
  TelnyxRTC: vi.fn(() => rtcInstance),
}));
vi.mock('../../channel/voice/voiceAPIClient', () => ({
  default: { getToken: vi.fn() },
}));

const buildCall = (overrides = {}) => ({
  id: 'call-1',
  direction: 'inbound',
  state: 'ringing',
  answer: vi.fn().mockResolvedValue(),
  hangup: vi.fn(),
  muteAudio: vi.fn(),
  unmuteAudio: vi.fn(),
  ...overrides,
});

const notify = call =>
  handlers['telnyx.notification']({ type: 'callUpdate', call });

describe('TelnyxVoiceClient', () => {
  beforeEach(async () => {
    VoiceAPI.getToken.mockResolvedValue({ token: 'jwt' });
    await TelnyxVoiceClient.initializeDevice(1);
  });

  afterEach(() => {
    TelnyxVoiceClient.destroyDevice();
    vi.clearAllMocks();
  });

  it('logs in with the JWT from the token endpoint', () => {
    expect(VoiceAPI.getToken).toHaveBeenCalledWith(1);
    expect(rtcInstance.connect).toHaveBeenCalled();
    expect(TelnyxVoiceClient.initialized).toBe(true);
  });

  it('answers an invite that arrives after joinClientCall starts waiting', async () => {
    const call = buildCall();
    const joining = TelnyxVoiceClient.joinClientCall();
    notify(call);

    await expect(joining).resolves.toBe(call);
    expect(call.answer).toHaveBeenCalled();
    expect(TelnyxVoiceClient.hasActiveConnection).toBe(true);
  });

  it('answers an invite that arrived before joinClientCall', async () => {
    const call = buildCall();
    notify(call);

    await TelnyxVoiceClient.joinClientCall();
    expect(call.answer).toHaveBeenCalled();
  });

  it('mutes through the active call', async () => {
    const call = buildCall();
    notify(call);
    await TelnyxVoiceClient.joinClientCall();

    TelnyxVoiceClient.setMuted(true);
    TelnyxVoiceClient.setMuted(false);
    expect(call.muteAudio).toHaveBeenCalled();
    expect(call.unmuteAudio).toHaveBeenCalled();
  });

  it('emits call:disconnected when the active call hangs up', async () => {
    const listener = vi.fn();
    TelnyxVoiceClient.addEventListener('call:disconnected', listener);
    const call = buildCall();
    notify(call);
    await TelnyxVoiceClient.joinClientCall();

    notify({ ...call, state: 'hangup' });
    expect(listener).toHaveBeenCalled();
    expect(TelnyxVoiceClient.hasActiveConnection).toBe(false);
    TelnyxVoiceClient.removeEventListener('call:disconnected', listener);
  });

  it('hangs up the active call on endClientCall', async () => {
    const call = buildCall();
    notify(call);
    await TelnyxVoiceClient.joinClientCall();
    call.state = 'active';

    TelnyxVoiceClient.endClientCall();
    expect(call.hangup).toHaveBeenCalled();
  });
});

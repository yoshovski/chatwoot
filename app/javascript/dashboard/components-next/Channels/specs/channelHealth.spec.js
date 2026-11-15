import { channelHealth, channelGroupForTab } from '../channelHealth';

const email = { channel_type: 'Channel::Email' };
const whatsapp = {
  channel_type: 'Channel::Whatsapp',
  connection_configured: true,
};

describe('channel health', () => {
  it('asks for setup when email has neither IMAP nor forwarding', () => {
    expect(channelHealth(email).status).toBe('setup');
  });

  it.each([
    { imap_enabled: true },
    { forwarding_enabled: true },
    { provider: 'google' },
    { provider: 'microsoft' },
  ])('recognizes configured email: %j', config => {
    expect(channelHealth({ ...email, ...config }).status).toBe('connected');
  });

  it('prioritizes expired authorization over configured email', () => {
    expect(
      channelHealth({
        ...email,
        imap_enabled: true,
        reauthorization_required: true,
      }).reason
    ).toBe('CHANNELS.HEALTH.REAUTHORIZE');
  });

  it('requires WhatsApp configuration before considering saved health', () => {
    expect(
      channelHealth({
        ...whatsapp,
        connection_configured: false,
        phone_number_health: { status: 'CONNECTED' },
      }).status
    ).toBe('setup');
  });

  it.each([
    'BANNED',
    'RESTRICTED',
    'RATE_LIMITED',
    'FLAGGED',
    'DISCONNECTED',
    'DELETED',
  ])('surfaces blocked WhatsApp status %s', status => {
    expect(
      channelHealth({ ...whatsapp, phone_number_health: { status } }).status
    ).toBe('attention');
  });

  it.each(['YELLOW', 'RED'])('surfaces WhatsApp quality %s', quality => {
    expect(
      channelHealth({
        ...whatsapp,
        phone_number_health: { status: 'CONNECTED', quality_rating: quality },
      }).status
    ).toBe('attention');
  });

  it('surfaces failed health checks even when the last saved result was connected', () => {
    expect(
      channelHealth({
        ...whatsapp,
        health_check_failed: true,
        phone_number_health: { status: 'CONNECTED' },
      }).reason
    ).toBe('CHANNELS.HEALTH.CHECK_FAILED');
  });

  it('distinguishes configured credentials from a connected provider check', () => {
    expect(channelHealth(whatsapp).reason).toBe(
      'CHANNELS.HEALTH.WHATSAPP_CONFIGURED'
    );
    expect(
      channelHealth({
        ...whatsapp,
        phone_number_health: { status: 'CONNECTED' },
      }).reason
    ).toBe('CHANNELS.HEALTH.WHATSAPP_CHECKED');
  });

  it('surfaces incomplete registration', () => {
    expect(
      channelHealth({
        ...whatsapp,
        phone_number_health: { platform_type: 'NOT_APPLICABLE' },
      }).reason
    ).toBe('CHANNELS.HEALTH.REGISTRATION');
  });
});

describe('old channel tabs', () => {
  it.each(['inbox-settings', 'csat', 'messages'])(
    'opens %s under Look and messages',
    tab => {
      expect(channelGroupForTab(tab)).toBe('messages');
    }
  );
  it.each(['collaborators', 'business-hours', 'team'])(
    'opens %s under Team and hours',
    tab => {
      expect(channelGroupForTab(tab)).toBe('team');
    }
  );
  it.each([
    undefined,
    'configuration',
    'bot-configuration',
    'whatsapp-health',
    'calls-configuration',
  ])('opens %s under Connection', tab => {
    expect(channelGroupForTab(tab)).toBe('connection');
  });
});

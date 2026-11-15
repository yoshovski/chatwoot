import { INBOX_TYPES } from 'dashboard/helper/inbox';

export const CHANNEL_STATES = {
  connected: { tone: 'live', label: 'CHANNELS.STATUS.CONNECTED' },
  attention: { tone: 'attention', label: 'CHANNELS.STATUS.ATTENTION' },
  setup: { tone: 'paused', label: 'CHANNELS.STATUS.SETUP' },
};

const state = (status, reason) => ({
  ...CHANNEL_STATES[status],
  status,
  reason,
});
const attention = reason => state('attention', reason);
const setup = reason => state('setup', reason);
const connected = reason => state('connected', reason);
const BLOCKED_STATUSES = [
  'BANNED',
  'RESTRICTED',
  'RATE_LIMITED',
  'FLAGGED',
  'DISCONNECTED',
  'DELETED',
];

// Configuration and the provider's last stored health check, never an assertion of live delivery.
export const channelHealth = inbox => {
  if (inbox.reauthorization_required)
    return attention('CHANNELS.HEALTH.REAUTHORIZE');
  if (inbox.channel_type === INBOX_TYPES.EMAIL) {
    if (
      inbox.imap_enabled ||
      ['google', 'microsoft'].includes(inbox.provider)
    ) {
      return connected('CHANNELS.HEALTH.EMAIL_CONFIGURED');
    }
    if (inbox.forwarding_enabled)
      return connected('CHANNELS.HEALTH.EMAIL_FORWARDING');
    return setup('CHANNELS.HEALTH.EMAIL_SETUP');
  }
  if (inbox.channel_type === INBOX_TYPES.WHATSAPP) {
    if (!inbox.connection_configured)
      return setup('CHANNELS.HEALTH.WHATSAPP_SETUP');
    const health = inbox.phone_number_health || {};
    if (inbox.health_check_failed)
      return attention('CHANNELS.HEALTH.CHECK_FAILED');
    if (
      BLOCKED_STATUSES.includes(health.status) ||
      ['YELLOW', 'RED'].includes(health.quality_rating)
    ) {
      return attention('CHANNELS.HEALTH.WHATSAPP_RESTRICTED');
    }
    if (
      health.platform_type === 'NOT_APPLICABLE' ||
      health.throughput_level === 'NOT_APPLICABLE'
    ) {
      return attention('CHANNELS.HEALTH.REGISTRATION');
    }
    return connected(
      health.status === 'CONNECTED'
        ? 'CHANNELS.HEALTH.WHATSAPP_CHECKED'
        : 'CHANNELS.HEALTH.WHATSAPP_CONFIGURED'
    );
  }
  return connected('CHANNELS.HEALTH.CONFIGURED');
};

export const CHANNEL_GROUPS = [
  { key: 'connection', label: 'CHANNELS.GROUPS.CONNECTION' },
  { key: 'messages', label: 'CHANNELS.GROUPS.MESSAGES' },
  { key: 'team', label: 'CHANNELS.GROUPS.TEAM' },
];

export const channelGroupForTab = tab => {
  if (['inbox-settings', 'csat', 'messages'].includes(tab)) return 'messages';
  if (['collaborators', 'business-hours', 'team'].includes(tab)) return 'team';
  return 'connection';
};

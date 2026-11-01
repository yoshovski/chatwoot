import { getWidgetForegroundColor } from 'shared/helpers/colorHelper';
import { sanitizeAllowedDomains } from 'dashboard/helper/URLHelper';

export const DEFAULT_WIDGET_HEIGHT = 640;
export const DEFAULT_REPLY_TIME = 'in_a_few_minutes';

// Launcher settings aren't stored on the inbox: the SDK reads them from window.chatwootSettings in the install
// snippet, and the settings page remembers them per inbox in local storage.
export const DEFAULT_SCRIPT_SETTINGS = {
  position: 'right',
  type: 'standard',
  launcherTitle: '',
  showHome: true,
};

const normalizeConversationStarters = starters =>
  (starters || []).map((starter, index) => ({
    id: starter.id || `saved-${index}`,
    title: starter.title || '',
    enabled: starter.enabled !== false,
    action_type: starter.action_type || 'message',
    target: starter.target || '',
  }));

export const serializeConversationStarters = starters =>
  starters
    .map(starter => ({
      id: starter.id,
      title: starter.title.trim(),
      enabled: starter.enabled,
      action_type: starter.action_type || 'message',
      target: (starter.target || '').trim(),
    }))
    .filter(starter => starter.title);

export const buildWidgetForm = (inbox, savedScriptSettings = {}) => {
  const automaticContrastColor = getWidgetForegroundColor(inbox.widget_color);
  const scriptSettings = { ...DEFAULT_SCRIPT_SETTINGS, ...savedScriptSettings };
  return {
    name: inbox.name || '',
    avatarUrl: inbox.avatar_url || '',
    widgetColor: inbox.widget_color,
    widgetTextColor: inbox.widget_text_color || automaticContrastColor,
    widgetIconColor: inbox.widget_icon_color || automaticContrastColor,
    isWidgetTextColorCustom: !!inbox.widget_text_color,
    isWidgetIconColorCustom: !!inbox.widget_icon_color,
    widgetHeight: inbox.widget_height || DEFAULT_WIDGET_HEIGHT,
    welcomeTitle: inbox.welcome_title || '',
    welcomeTagline: inbox.welcome_tagline || '',
    position: scriptSettings.position,
    bubbleType: scriptSettings.type,
    launcherTitle: scriptSettings.launcherTitle,
    showHome: scriptSettings.showHome,
    websiteUrl: inbox.website_url || '',
    allowedDomains: inbox.allowed_domains || '',
    replyTime: inbox.reply_time || DEFAULT_REPLY_TIME,
    replyTimeMessage: inbox.reply_time_message || '',
    conversationStarters: normalizeConversationStarters(
      inbox.conversation_starters
    ),
    greetingEnabled: !!inbox.greeting_enabled,
    greetingMessage: inbox.greeting_message || '',
    emailCollectEnabled: !!inbox.enable_email_collect,
    continuityViaEmail: !!inbox.continuity_via_email,
    allowMessagesAfterResolved: !!inbox.allow_messages_after_resolved,
    selectedFeatureFlags: [...(inbox.selected_feature_flags || [])],
    hmacMandatory: !!inbox.hmac_mandatory,
    demoModeEnabled: !!inbox.demo_mode_enabled,
    demoSlug: inbox.demo_slug || '',
    portalSlug: inbox.help_center?.slug || '',
    senderNameType: inbox.sender_name_type,
    businessName: inbox.business_name || '',
  };
};

export const pickScriptSettings = form => ({
  position: form.position,
  type: form.bubbleType,
  launcherTitle: form.launcherTitle,
  showHome: form.showHome,
});

// Same request the settings page has always sent, plus the domain and identity settings now edited on this page.
export const buildWidgetPayload = (
  form,
  { inboxId, portals, canEmailContinuity }
) => ({
  id: inboxId,
  name: form.name.trim(),
  enable_email_collect: form.emailCollectEnabled,
  allow_messages_after_resolved: form.allowMessagesAfterResolved,
  greeting_enabled: form.greetingEnabled,
  greeting_message: form.greetingMessage || '',
  portal_id: form.portalSlug
    ? portals.find(portal => portal.slug === form.portalSlug)?.id || null
    : null,
  sender_name_type: form.senderNameType,
  business_name: form.businessName || null,
  channel: {
    widget_color: form.widgetColor,
    widget_text_color: form.isWidgetTextColorCustom ? form.widgetTextColor : '',
    widget_icon_color: form.isWidgetIconColorCustom ? form.widgetIconColor : '',
    widget_height: form.widgetHeight,
    conversation_starters: serializeConversationStarters(
      form.conversationStarters
    ),
    website_url: form.websiteUrl,
    allowed_domains: sanitizeAllowedDomains(form.allowedDomains),
    welcome_title: form.welcomeTitle || '',
    welcome_tagline: form.welcomeTagline || '',
    selectedFeatureFlags: form.selectedFeatureFlags,
    reply_time: form.replyTime || DEFAULT_REPLY_TIME,
    reply_time_message: form.replyTimeMessage.trim(),
    continuity_via_email: canEmailContinuity && form.continuityViaEmail,
    hmac_mandatory: form.hmacMandatory,
    demo_mode_enabled: form.demoModeEnabled,
    demo_slug: form.demoSlug.trim() || null,
  },
});

// The widget preview protocol's config (see widget/helpers/previewMode.js).
export const buildPreviewConfig = (form, { locale }) => ({
  widgetColor: form.widgetColor,
  widgetTextColor: form.isWidgetTextColorCustom
    ? form.widgetTextColor
    : getWidgetForegroundColor(form.widgetColor),
  widgetIconColor: form.isWidgetIconColorCustom
    ? form.widgetIconColor
    : getWidgetForegroundColor(form.widgetColor),
  welcomeTitle: form.welcomeTitle,
  welcomeTagline: form.welcomeTagline,
  websiteName: form.name,
  avatarUrl: form.avatarUrl,
  position: form.position,
  bubbleType: form.bubbleType,
  launcherTitle: form.launcherTitle,
  showHome: form.showHome,
  replyTime: form.replyTime,
  replyTimeMessage: form.replyTimeMessage.trim(),
  conversationStarters: serializeConversationStarters(
    form.conversationStarters
  ),
  enabledFeatures: form.selectedFeatureFlags,
  locale,
  // Reserved for proactive openers.
  opener: null,
});

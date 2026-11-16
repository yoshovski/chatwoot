import { reactive } from 'vue';
import { MESSAGE_TYPE } from 'widget/helpers/constants';
import { getWidgetForegroundColor } from 'shared/helpers/colorHelper';

// The inbox settings page and the AI agent test frame the real widget in preview mode (GET /widget/preview) and
// drive it with postMessage. The page shares this origin, so nothing else may change what the preview shows.
// In test mode the visitor's messages go to the framing page, which asks the AI agent and sends the reply back.
export const PREVIEW_MESSAGE = 'chatoctave:preview';
export const PREVIEW_READY = 'chatoctave:preview-ready';
export const PREVIEW_VIEW_CHANGED = 'chatoctave:preview-view';
export const PREVIEW_SEND = 'chatoctave:preview-send';

export const PREVIEW_VIEWS = {
  HOME: 'home',
  CONVERSATION: 'conversation',
  LAUNCHER: 'launcher',
};

// Settings that live on the channel config the widget reads everywhere.
const CHANNEL_KEYS = [
  'avatarUrl',
  'conversationStarters',
  'enabledFeatures',
  'replyTime',
  'replyTimeMessage',
  'websiteName',
  'welcomeTagline',
  'welcomeTitle',
  'widgetIconColor',
];

// Settings the SDK applies on a website (from the install snippet); the preview applies them itself.
// opener is reserved for proactive openers and isn't drawn yet. testMode unlocks the composer.
const LAUNCHER_KEYS = [
  'bubbleType',
  'launcherTitle',
  'opener',
  'position',
  'showHome',
  'testMode',
];

export const isPreviewMode = () => window.chatwootWebChannel?.preview === true;

export const previewState = reactive({
  view: PREVIEW_VIEWS.HOME,
  bubbleType: 'standard',
  launcherTitle: '',
  opener: null,
  position: 'right',
  showHome: true,
  testMode: false,
});

export const isPreviewTestMode = () => isPreviewMode() && previewState.testMode;

export const setWidgetColorVariables = (widgetColor, widgetTextColor) => {
  const { style } = document.documentElement;
  if (widgetColor) style.setProperty('--widget-color', widgetColor);
  if (widgetTextColor)
    style.setProperty('--widget-text-color', widgetTextColor);
};

// What a visitor sees after asking the AI agent one question. Same shape as the messages the AI agent posts.
export const buildSampleMessages = (t, agentName) => {
  const now = Math.floor(Date.now() / 1000);
  const sender = {
    type: 'captain_assistant',
    name: agentName || t('PREVIEW.SAMPLE.AGENT_NAME'),
    available_name: agentName || t('PREVIEW.SAMPLE.AGENT_NAME'),
  };

  return [
    {
      id: 1,
      content: t('PREVIEW.SAMPLE.GREETING'),
      content_type: 'text',
      content_attributes: {},
      message_type: MESSAGE_TYPE.OUTGOING,
      created_at: now - 120,
      sender,
    },
    {
      id: 2,
      content: t('PREVIEW.SAMPLE.QUESTION'),
      content_type: 'text',
      content_attributes: {},
      message_type: MESSAGE_TYPE.INCOMING,
      created_at: now - 60,
    },
    {
      id: 3,
      content: t('PREVIEW.SAMPLE.ANSWER'),
      content_type: 'input_select',
      content_attributes: {
        items: [
          {
            title: t('PREVIEW.SAMPLE.SUGGESTIONS.TRACK.TITLE'),
            value: t('PREVIEW.SAMPLE.SUGGESTIONS.TRACK.VALUE'),
          },
          {
            title: t('PREVIEW.SAMPLE.SUGGESTIONS.RETURNS.TITLE'),
            value: t('PREVIEW.SAMPLE.SUGGESTIONS.RETURNS.VALUE'),
          },
        ],
        submit_value: true,
      },
      message_type: MESSAGE_TYPE.OUTGOING,
      created_at: now,
      sender,
    },
  ];
};

export const setPreviewMessages = (store, messages) => {
  store.commit('conversation/clearConversations');
  store.commit('conversation/setMessagesInConversation', messages);
  // Everything shown has been read, so the home card shows no unread badge.
  store.commit(
    'conversation/setMetaUserLastSeenAt',
    Math.max(...messages.map(message => message.created_at), 0)
  );
};

export const readPreviewMessage = event => {
  if (event.origin !== window.location.origin) return null;
  if (event.source !== window.parent) return null;
  if (event.data?.type !== PREVIEW_MESSAGE) return null;
  return event.data;
};

const notifyParent = message =>
  window.parent.postMessage(message, window.location.origin);

// A message the visitor typed or picked from the starters, or (as submitted) a suggestion or form answered on an
// earlier message. The framing page keeps the answer when it sends the conversation back.
export const sendPreviewMessage = (content, submitted = null) => {
  previewState.view = PREVIEW_VIEWS.CONVERSATION;
  notifyParent({
    type: PREVIEW_VIEW_CHANGED,
    view: PREVIEW_VIEWS.CONVERSATION,
  });
  notifyParent({ type: PREVIEW_SEND, content, submitted });
};

const showView = (router, view) => {
  previewState.view = view;
  if (view === PREVIEW_VIEWS.LAUNCHER) return;

  const showsHome = view === PREVIEW_VIEWS.HOME && previewState.showHome;
  router.replace({ name: showsHome ? 'home' : 'messages' });
};

export const changePreviewView = (router, view) => {
  showView(router, view);
  notifyParent({ type: PREVIEW_VIEW_CHANGED, view });
};

const pick = (source, keys) =>
  Object.fromEntries(
    keys.filter(key => key in source).map(k => [k, source[k]])
  );

export const applyPreviewUpdate = (
  { store, router, setLocale },
  { config = {}, view, messages, typing }
) => {
  Object.assign(window.chatwootWebChannel, pick(config, CHANNEL_KEYS));
  Object.assign(previewState, pick(config, LAUNCHER_KEYS));

  if (config.widgetColor) {
    const textColor =
      config.widgetTextColor || getWidgetForegroundColor(config.widgetColor);
    window.chatwootWebChannel.widgetColor = config.widgetColor;
    store.dispatch('appConfig/setWidgetColor', config.widgetColor);
    store.dispatch('appConfig/setWidgetTextColor', textColor);
    setWidgetColorVariables(config.widgetColor, textColor);
  }
  if (config.darkMode)
    store.dispatch('appConfig/setColorScheme', config.darkMode);
  if (config.locale) setLocale(config.locale);
  if (messages) setPreviewMessages(store, messages);
  if (typing !== undefined)
    store.commit('conversation/toggleAgentTypingStatus', {
      status: typing ? 'on' : 'off',
    });

  // The AI agent test sends each new message without a view, so the visitor stays where they are.
  if (view) showView(router, view);
};

// Preview mode never calls the API or opens a socket: it starts from the sample and waits for the settings page.
export const startPreview = ({ store, router, t, setLocale }) => {
  setPreviewMessages(
    store,
    buildSampleMessages(t, window.chatwootWebChannel.previewAgentName)
  );
  store.dispatch('appConfig/toggleWidgetOpen', true);
  window.addEventListener('message', event => {
    const update = readPreviewMessage(event);
    if (update) applyPreviewUpdate({ store, router, setLocale }, update);
  });
  notifyParent({ type: PREVIEW_READY });
};

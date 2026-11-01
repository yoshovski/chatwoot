import { ref } from 'vue';
import { flushPromises, mount } from '@vue/test-utils';
import InboxesAPI from 'dashboard/api/inboxes';
import CaptainAssistantAPI from 'dashboard/api/captain/assistant';
import CaptainInboxesAPI from 'dashboard/api/captain/inboxes';
import WidgetSettings from './WidgetSettings.vue';
import WidgetAiAgentCard from './WidgetAiAgentCard.vue';
import WidgetLivePreview from 'dashboard/components-next/Inbox/WidgetLivePreview.vue';

const dispatch = vi.fn();
const captainEnabled = ref(true);

vi.mock('vue-router', () => ({ onBeforeRouteLeave: vi.fn() }));
vi.mock('dashboard/api/inboxes', () => ({
  default: { getWidgetPreviewToken: vi.fn() },
}));
vi.mock('dashboard/api/captain/assistant', () => ({
  default: { get: vi.fn() },
}));
vi.mock('dashboard/api/captain/inboxes', () => ({
  default: { get: vi.fn() },
}));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
  useMapGetter: key =>
    ({
      'accounts/isFeatureEnabledonAccount': ref(() => false),
      'globalConfig/isOnChatwootCloud': ref(false),
      'portals/allPortals': ref([]),
      'inboxes/getUIFlags': ref({ isUpdating: false }),
    })[key],
}));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    currentAccount: ref({ id: 1, locale: 'en' }),
    isCloudFeatureEnabled: () => captainEnabled.value,
  }),
}));

const inbox = {
  id: 7,
  name: 'Acme Store',
  channel_type: 'Channel::WebWidget',
  widget_color: '#1f93ff',
  welcome_title: 'Hi there',
  welcome_tagline: '',
  website_url: 'https://www.example.com',
  website_token: 'token',
  web_widget_script:
    "\n    <script>\n      window.chatwootSDK.run({ websiteToken: 'token' })\n    </script>\n    ",
  greeting_enabled: true,
  greeting_message: 'Hello!',
  selected_feature_flags: ['attachments'],
  reply_time: 'in_a_few_minutes',
  conversation_starters: [],
  sender_name_type: 'friendly',
};

const connectAiAgent = connected => {
  CaptainAssistantAPI.get.mockResolvedValue({
    data: { payload: [{ id: 3, name: 'Ava', avatar_url: '' }] },
  });
  CaptainInboxesAPI.get.mockResolvedValue({
    data: { payload: connected ? [{ id: inbox.id }] : [{ id: 99 }] },
  });
};

const mountSettings = async () => {
  const wrapper = mount(WidgetSettings, {
    props: { inbox },
    global: {
      stubs: {
        Editor: true,
        GreetingsEditor: true,
        SenderNameExamplePreview: true,
        HmacSecretKey: true,
        RouterLink: { template: '<a><slot /></a>' },
      },
    },
    attachTo: document.body,
  });
  await flushPromises();
  return wrapper;
};

const greetingToggle = wrapper =>
  wrapper
    .findAll('span')
    .find(
      span =>
        span.text() ===
        'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_TOGGLE.LABEL'
    );

describe('WidgetSettings', () => {
  beforeEach(() => {
    captainEnabled.value = true;
    InboxesAPI.getWidgetPreviewToken.mockResolvedValue({
      data: { token: 'preview', expires_at: Date.now() / 1000 + 900 },
    });
  });

  afterEach(() => {
    vi.useRealTimers();
    document.body.innerHTML = '';
  });

  it('shows the AI agent card instead of the greeting when an AI agent answers', async () => {
    connectAiAgent(true);
    const wrapper = await mountSettings();

    const card = wrapper.findComponent(WidgetAiAgentCard);
    expect(card.exists()).toBe(true);
    expect(card.text()).toContain('Ava');
    expect(greetingToggle(wrapper)).toBeUndefined();
  });

  it('keeps the greeting for inboxes without an AI agent', async () => {
    connectAiAgent(false);
    const wrapper = await mountSettings();

    expect(wrapper.findComponent(WidgetAiAgentCard).exists()).toBe(false);
    expect(greetingToggle(wrapper)).toBeDefined();
  });

  it('keeps the greeting when the AI agent feature is off', async () => {
    captainEnabled.value = false;
    const wrapper = await mountSettings();

    expect(CaptainAssistantAPI.get).not.toHaveBeenCalled();
    expect(greetingToggle(wrapper)).toBeDefined();
  });

  it('starts with Advanced collapsed', async () => {
    connectAiAgent(false);
    const wrapper = await mountSettings();

    const advanced = wrapper
      .findAll('button[aria-expanded]')
      .find(button =>
        button.text().includes('INBOX_MGMT.WIDGET_SETTINGS.ADVANCED.TITLE')
      );
    expect(advanced.attributes('aria-expanded')).toBe('false');
    expect(wrapper.text()).not.toContain(
      'INBOX_MGMT.WIDGET_SETTINGS.ADVANCED.HOME_SCREEN.TITLE'
    );

    await advanced.trigger('click');
    expect(advanced.attributes('aria-expanded')).toBe('true');
    expect(wrapper.text()).toContain(
      'INBOX_MGMT.WIDGET_SETTINGS.ADVANCED.HOME_SCREEN.TITLE'
    );
  });

  it('sends form changes to the preview after a short pause', async () => {
    connectAiAgent(false);
    const wrapper = await mountSettings();
    vi.useFakeTimers({ toFake: ['setTimeout', 'clearTimeout'] });

    const frame = wrapper.find('iframe').element.contentWindow;
    const postMessage = vi.spyOn(frame, 'postMessage');
    window.dispatchEvent(
      new MessageEvent('message', {
        data: { type: 'chatoctave:preview-ready' },
        origin: window.location.origin,
        source: frame,
      })
    );
    await flushPromises();
    postMessage.mockClear();

    const titleInput = wrapper
      .findAll('input')
      .find(input => input.element.value === 'Hi there');
    await titleInput.setValue('Welcome to Acme');
    expect(postMessage).not.toHaveBeenCalled();

    vi.advanceTimersByTime(250);
    expect(postMessage).toHaveBeenCalledTimes(1);
    const [payload, origin] = postMessage.mock.calls[0];
    expect(origin).toBe(window.location.origin);
    expect(payload).toMatchObject({
      type: 'chatoctave:preview',
      view: 'home',
      config: {
        welcomeTitle: 'Welcome to Acme',
        websiteName: 'Acme Store',
        widgetColor: '#1f93ff',
        opener: null,
      },
    });
  });

  it('saves the same request shape and shows the save bar only when dirty', async () => {
    connectAiAgent(false);
    const wrapper = await mountSettings();
    const saveBarText = 'CAPTAIN.ASSISTANTS.SETTINGS.SAVE_BAR.UNSAVED';
    expect(wrapper.text()).not.toContain(saveBarText);

    const titleInput = wrapper
      .findAll('input')
      .find(input => input.element.value === 'Hi there');
    await titleInput.setValue('Welcome to Acme');
    expect(wrapper.text()).toContain(saveBarText);

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'CAPTAIN.ASSISTANTS.SETTINGS.SAVE')
      .trigger('click');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith(
      'inboxes/updateInbox',
      expect.objectContaining({
        id: 7,
        name: 'Acme Store',
        greeting_enabled: true,
        channel: expect.objectContaining({
          welcome_title: 'Welcome to Acme',
          widget_color: '#1f93ff',
          website_url: 'https://www.example.com',
          selectedFeatureFlags: ['attachments'],
        }),
      })
    );
  });

  it('passes the inbox to the live preview', async () => {
    connectAiAgent(false);
    const wrapper = await mountSettings();

    expect(wrapper.findComponent(WidgetLivePreview).props('inboxId')).toBe(7);
  });
});

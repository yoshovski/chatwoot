import { ref } from 'vue';
import { flushPromises, mount } from '@vue/test-utils';
import InboxesAPI from 'dashboard/api/inboxes';
import WidgetSettings from './WidgetSettings.vue';
import WidgetAiAgentCard from './WidgetAiAgentCard.vue';
import WidgetLivePreview from 'dashboard/components-next/Inbox/WidgetLivePreview.vue';

const dispatch = vi.fn();

vi.mock('vue-router', () => ({
  onBeforeRouteLeave: vi.fn(),
  onBeforeRouteUpdate: vi.fn(),
}));
vi.mock('dashboard/api/inboxes', () => ({
  default: { getWidgetPreviewToken: vi.fn() },
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

const mountSettings = async (props = {}) => {
  const wrapper = mount(WidgetSettings, {
    props: { inbox, ...props },
    global: {
      stubs: {
        Editor: true,
        SettingsHelp: true,
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
    InboxesAPI.getWidgetPreviewToken.mockResolvedValue({
      data: { token: 'preview', expires_at: Date.now() / 1000 + 900 },
    });
  });

  afterEach(() => {
    vi.useRealTimers();
    document.body.innerHTML = '';
  });

  it('shows the connected AI agent instead of the greeting', async () => {
    const wrapper = await mountSettings({
      section: 'conversation',
      hasCaptain: true,
      inbox: { ...inbox, captain_assistant: { id: 3, name: 'Ava' } },
    });

    const card = wrapper.findComponent(WidgetAiAgentCard);
    expect(card.exists()).toBe(true);
    expect(card.text()).toContain('Ava');
    expect(greetingToggle(wrapper)).toBeUndefined();
  });

  it('keeps the greeting for inboxes without an AI agent', async () => {
    const wrapper = await mountSettings({
      section: 'conversation',
      hasCaptain: true,
    });

    expect(wrapper.findComponent(WidgetAiAgentCard).exists()).toBe(false);
    expect(greetingToggle(wrapper)).toBeDefined();
  });

  it('retains edits when navigating between widget sections', async () => {
    const wrapper = await mountSettings();
    const mint = wrapper
      .findAll('button[aria-pressed]')
      .find(button => button.text().endsWith('PALETTE.MINT'));
    await mint.trigger('click');
    await wrapper.setProps({ section: 'installation' });

    expect(wrapper.text()).toContain(
      'INBOX_MGMT.WIDGET_SETTINGS.INSTALLATION.SCRIPT'
    );
    expect(wrapper.text()).not.toContain('PALETTE.MINT');
    expect(
      wrapper.findComponent(WidgetLivePreview).props('config').widgetColor
    ).toBe('#dcf4eb');

    await wrapper.setProps({ section: 'appearance' });
    expect(
      wrapper
        .findAll('button[aria-pressed="true"]')
        .some(button => button.text().endsWith('PALETTE.MINT'))
    ).toBe(true);
    expect(wrapper.text()).toContain(
      'INBOX_MGMT.WEBSITE_SETTINGS.UNSAVED_WIDGET'
    );
  });

  it('previews and saves a preset without adding a custom text or icon color', async () => {
    const wrapper = await mountSettings();
    const mint = wrapper
      .findAll('button[aria-pressed]')
      .find(button => button.text().endsWith('PALETTE.MINT'));
    expect(mint.attributes('aria-pressed')).toBe('false');

    await mint.trigger('click');
    expect(mint.attributes('aria-pressed')).toBe('true');
    expect(
      wrapper.findComponent(WidgetLivePreview).props('config')
    ).toMatchObject({
      widgetColor: '#dcf4eb',
      widgetTextColor: '#37546d',
      widgetIconColor: '#37546d',
    });
    await wrapper
      .findAll('button')
      .find(
        button => button.text() === 'INBOX_MGMT.WEBSITE_SETTINGS.SAVE_WIDGET'
      )
      .trigger('click');
    expect(dispatch).toHaveBeenCalledWith(
      'inboxes/updateInbox',
      expect.objectContaining({
        channel: expect.objectContaining({
          widget_color: '#dcf4eb',
          widget_text_color: '',
          widget_icon_color: '',
        }),
      })
    );
  });

  it('sends form changes to the preview after a short pause', async () => {
    const wrapper = await mountSettings({ section: 'welcome' });
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
    const wrapper = await mountSettings({ section: 'welcome' });
    const saveBarText = 'INBOX_MGMT.WEBSITE_SETTINGS.UNSAVED_WIDGET';
    expect(wrapper.text()).not.toContain(saveBarText);

    const titleInput = wrapper
      .findAll('input')
      .find(input => input.element.value === 'Hi there');
    await titleInput.setValue('Welcome to Acme');
    expect(wrapper.text()).toContain(saveBarText);

    await wrapper
      .findAll('button')
      .find(
        button => button.text() === 'INBOX_MGMT.WEBSITE_SETTINGS.SAVE_WIDGET'
      )
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
    const wrapper = await mountSettings();

    expect(wrapper.findComponent(WidgetLivePreview).props('inboxId')).toBe(7);
  });
});

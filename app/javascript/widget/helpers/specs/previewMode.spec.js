import { createConsumer } from '@rails/actioncable';
import { mount } from '@vue/test-utils';
import { reactive } from 'vue';
import { API } from 'widget/helpers/axios';
import { connectWidgetSocket } from 'widget/helpers/actionCable';
import store from 'widget/store';
import ChatInputWrap from 'widget/components/ChatInputWrap.vue';
import {
  applyPreviewUpdate,
  previewState,
  startPreview,
  PREVIEW_MESSAGE,
  PREVIEW_READY,
} from '../previewMode';

vi.mock('@rails/actioncable', () => ({
  createConsumer: vi.fn(() => ({ subscriptions: { create: () => ({}) } })),
}));

const t = key => key;
const router = { replace: vi.fn() };
const setLocale = vi.fn();

const postFromParent = (data, origin = window.location.origin) =>
  window.dispatchEvent(
    new MessageEvent('message', { data, origin, source: window.parent })
  );

const messages = () => Object.values(store.state.conversation.conversations);

describe('widget preview mode', () => {
  beforeEach(() => {
    window.chatwootWebChannel = reactive({
      preview: true,
      previewAgentName: 'Ava',
      widgetColor: '#1f93ff',
      welcomeTitle: 'Saved title',
      enabledFeatures: [],
    });
    Object.assign(previewState, {
      view: 'home',
      opener: null,
      position: 'right',
      showHome: true,
    });
    vi.spyOn(window.parent, 'postMessage');
    startPreview({ store, router, t, setLocale });
  });

  it('rejects every API call before it is sent', async () => {
    const adapter = vi.fn();

    await expect(
      API.get('/api/v1/widget/messages', { adapter })
    ).rejects.toThrow('The widget preview makes no API calls');
    await expect(
      store.dispatch('conversation/sendMessage', { content: 'Hi' })
    ).resolves.toBeUndefined();
    expect(adapter).not.toHaveBeenCalled();
  });

  it('opens no socket', () => {
    expect(connectWidgetSocket({}, 'pubsub-token')).toBeNull();
    expect(createConsumer).not.toHaveBeenCalled();
  });

  it('seeds the sample conversation and tells the settings page it is ready', () => {
    const [greeting, question, answer] = messages();

    expect(messages()).toHaveLength(3);
    expect(greeting.sender).toMatchObject({
      type: 'captain_assistant',
      name: 'Ava',
    });
    expect(question.message_type).toBe(0);
    expect(answer.content_type).toBe('input_select');
    expect(answer.content_attributes.captain_sources).toHaveLength(1);
    expect(answer.content_attributes.items).toHaveLength(2);
    expect(store.getters['conversation/getUnreadMessageCount']).toBe(0);
    expect(window.parent.postMessage).toHaveBeenCalledWith(
      { type: PREVIEW_READY },
      window.location.origin
    );
  });

  it('ignores a message from another origin', () => {
    postFromParent(
      { type: PREVIEW_MESSAGE, config: { welcomeTitle: 'Injected' } },
      'https://attacker.example'
    );

    expect(window.chatwootWebChannel.welcomeTitle).toBe('Saved title');
    expect(router.replace).not.toHaveBeenCalled();
  });

  it('applies colour, title and opener from the settings page', () => {
    postFromParent({
      type: PREVIEW_MESSAGE,
      config: {
        widgetColor: '#ff0000',
        welcomeTitle: 'Hello from the form',
        opener: { text: 'Need help choosing?' },
        locale: 'de',
      },
      view: 'conversation',
    });

    expect(store.getters['appConfig/getWidgetColor']).toBe('#ff0000');
    expect(
      document.documentElement.style.getPropertyValue('--widget-color')
    ).toBe('#ff0000');
    expect(window.chatwootWebChannel.welcomeTitle).toBe('Hello from the form');
    expect(previewState.opener).toEqual({ text: 'Need help choosing?' });
    expect(setLocale).toHaveBeenCalledWith('de');
    expect(router.replace).toHaveBeenCalledWith({ name: 'messages' });
  });

  it('opens on the conversation when the home screen is off', () => {
    applyPreviewUpdate(
      { store, router, setLocale },
      { config: { showHome: false }, view: 'home' }
    );

    expect(router.replace).toHaveBeenCalledWith({ name: 'messages' });
  });

  it('shows the closed launcher without changing route', () => {
    applyPreviewUpdate(
      { store, router, setLocale },
      { config: { position: 'left' }, view: 'launcher' }
    );

    expect(previewState).toMatchObject({ view: 'launcher', position: 'left' });
    expect(router.replace).not.toHaveBeenCalled();
  });

  it('replaces the sample with the messages it is sent', () => {
    const message = {
      id: 42,
      content: 'Looking for a gift?',
      content_type: 'text',
      content_attributes: {},
      message_type: 1,
      created_at: 1700000000,
    };

    postFromParent({ type: PREVIEW_MESSAGE, messages: [message] });

    expect(messages()).toEqual([message]);
  });

  it('keeps the composer visible but does not send', async () => {
    const onSendMessage = vi.fn();
    const wrapper = mount(ChatInputWrap, {
      props: { onSendMessage },
      global: {
        plugins: [store],
        mocks: { $t: key => key },
        directives: { onClickaway: {} },
      },
    });

    const textarea = wrapper.find('textarea');
    expect(textarea.attributes('disabled')).toBeDefined();
    expect(wrapper.text()).toContain('PREVIEW.COMPOSER_HINT');
    expect(
      wrapper.find('button[type="submit"]').attributes('disabled')
    ).toBeDefined();

    await wrapper.setData({ userInput: 'Hello' });
    wrapper.vm.handleButtonClick();
    expect(onSendMessage).not.toHaveBeenCalled();
  });
});

import { flushPromises, mount } from '@vue/test-utils';
import InboxesAPI from 'dashboard/api/inboxes';
import WidgetLivePreview from './WidgetLivePreview.vue';

vi.mock('dashboard/api/inboxes', () => ({
  default: { getWidgetPreviewToken: vi.fn() },
}));

const NOW = new Date('2026-11-01T10:00:00Z').getTime();
const TOKEN_LIFETIME_S = 15 * 60;

const tokenResponse = token => ({
  data: { token, expires_at: Math.floor(Date.now() / 1000) + TOKEN_LIFETIME_S },
});

const config = { widgetColor: '#1f93ff', welcomeTitle: 'Hi there' };

const mountPreview = async () => {
  const wrapper = mount(WidgetLivePreview, {
    props: { inboxId: 7, config },
    attachTo: document.body,
  });
  await flushPromises();
  return wrapper;
};

const frameWindow = wrapper => wrapper.find('iframe').element.contentWindow;

const postFromWidget = (wrapper, data, source = frameWindow(wrapper)) =>
  window.dispatchEvent(
    new MessageEvent('message', {
      data,
      origin: window.location.origin,
      source,
    })
  );

const markReady = async wrapper => {
  const postMessage = vi.spyOn(frameWindow(wrapper), 'postMessage');
  postFromWidget(wrapper, { type: 'chatoctave:preview-ready' });
  await flushPromises();
  return postMessage;
};

const lastPayload = postMessage => postMessage.mock.calls.at(-1)[0];

describe('WidgetLivePreview', () => {
  beforeEach(() => {
    vi.useFakeTimers({ toFake: ['setTimeout', 'clearTimeout', 'Date'] });
    vi.setSystemTime(NOW);
    InboxesAPI.getWidgetPreviewToken
      .mockResolvedValueOnce(tokenResponse('first-token'))
      .mockResolvedValueOnce(tokenResponse('second-token'));
  });

  afterEach(() => {
    vi.useRealTimers();
    document.body.innerHTML = '';
  });

  it('loads the widget preview page with a preview token', async () => {
    const wrapper = await mountPreview();

    expect(InboxesAPI.getWidgetPreviewToken).toHaveBeenCalledWith(7);
    expect(wrapper.find('iframe').attributes('src')).toBe(
      '/widget/preview?token=first-token'
    );
  });

  it('sends the settings once the widget is ready', async () => {
    const wrapper = await mountPreview();
    const postMessage = await markReady(wrapper);

    expect(postMessage).toHaveBeenCalledWith(
      {
        type: 'chatoctave:preview',
        config: { ...config, darkMode: 'light' },
        view: 'home',
      },
      window.location.origin
    );
  });

  it('debounces form changes into one payload', async () => {
    const wrapper = await mountPreview();
    const postMessage = await markReady(wrapper);
    postMessage.mockClear();

    await wrapper.setProps({ config: { ...config, welcomeTitle: 'H' } });
    await wrapper.setProps({ config: { ...config, welcomeTitle: 'Hello' } });
    expect(postMessage).not.toHaveBeenCalled();

    vi.advanceTimersByTime(250);
    expect(postMessage).toHaveBeenCalledTimes(1);
    expect(lastPayload(postMessage).config.welcomeTitle).toBe('Hello');
  });

  it('switches the previewed screen and theme', async () => {
    const wrapper = await mountPreview();
    const postMessage = await markReady(wrapper);

    const conversation = wrapper
      .findAll('button[aria-pressed]')
      .find(
        button =>
          button.text() === 'INBOX_MGMT.WIDGET_PREVIEW.VIEWS.CONVERSATION'
      );
    await conversation.trigger('click');

    expect(conversation.attributes('aria-pressed')).toBe('true');
    expect(lastPayload(postMessage).view).toBe('conversation');

    await wrapper
      .find('button[aria-label="INBOX_MGMT.WIDGET_PREVIEW.DARK"]')
      .trigger('click');
    expect(lastPayload(postMessage).config.darkMode).toBe('dark');
  });

  it('follows a screen change made inside the widget', async () => {
    const wrapper = await mountPreview();
    await markReady(wrapper);

    postFromWidget(wrapper, { type: 'chatoctave:preview-view', view: 'home' });
    postFromWidget(wrapper, {
      type: 'chatoctave:preview-view',
      view: 'launcher',
    });
    await flushPromises();

    const pressed = wrapper.find('button[aria-pressed="true"]');
    expect(pressed.text()).toBe('INBOX_MGMT.WIDGET_PREVIEW.VIEWS.LAUNCHER');
  });

  it('ignores messages from other windows', async () => {
    const wrapper = await mountPreview();
    const postMessage = vi.spyOn(frameWindow(wrapper), 'postMessage');

    postFromWidget(wrapper, { type: 'chatoctave:preview-ready' }, window);
    await flushPromises();

    expect(postMessage).not.toHaveBeenCalled();
  });

  it('refreshes the token a minute before it expires', async () => {
    const wrapper = await mountPreview();

    vi.advanceTimersByTime((TOKEN_LIFETIME_S - 61) * 1000);
    expect(InboxesAPI.getWidgetPreviewToken).toHaveBeenCalledTimes(1);

    vi.advanceTimersByTime(1000);
    await flushPromises();
    expect(InboxesAPI.getWidgetPreviewToken).toHaveBeenCalledTimes(2);
    expect(wrapper.find('iframe').attributes('src')).toBe(
      '/widget/preview?token=second-token'
    );
  });
});

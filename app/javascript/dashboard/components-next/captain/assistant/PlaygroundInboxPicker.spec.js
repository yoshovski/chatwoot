import { mount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import PlaygroundInboxPicker from './PlaygroundInboxPicker.vue';

const mocks = vi.hoisted(() => ({ dispatch: vi.fn(), inboxes: null }));

vi.mock('dashboard/composables/store.js', () => ({
  useStore: () => ({ dispatch: mocks.dispatch }),
  useMapGetter: () => mocks.inboxes,
}));

const widgetInbox = extra => ({
  id: 1,
  name: 'Website',
  channel_type: 'Channel::WebWidget',
  widget_color: '#336699',
  website_token: 'token123',
  demo_mode_enabled: true,
  ...extra,
});

const mountPicker = () =>
  mount(PlaygroundInboxPicker, {
    props: { assistantId: 7 },
    global: { stubs: { Select: true, NextButton: true } },
  });

describe('PlaygroundInboxPicker', () => {
  beforeEach(() => {
    mocks.dispatch.mockResolvedValue();
  });

  it('selects the first web widget inbox and links to its demo page', async () => {
    mocks.inboxes = ref([
      { id: 9, name: 'Email', channel_type: 'Channel::Email' },
      widgetInbox(),
    ]);
    const wrapper = mountPicker();
    await flushPromises();

    expect(mocks.dispatch).toHaveBeenCalledWith('captainInboxes/get', {
      assistantId: 7,
    });
    expect(wrapper.emitted('update:modelValue').at(-1)[0]).toMatchObject({
      id: 1,
    });
  });

  it('offers no demo link until an inbox with demo mode is selected', async () => {
    mocks.inboxes = ref([widgetInbox({ demo_mode_enabled: false })]);
    const wrapper = mountPicker();
    await flushPromises();
    await wrapper.setProps({
      modelValue: widgetInbox({ demo_mode_enabled: false }),
    });

    expect(wrapper.find('[data-test="playground-demo-link"]').exists()).toBe(
      false
    );

    await wrapper.setProps({ modelValue: widgetInbox() });

    expect(
      wrapper.get('[data-test="playground-demo-link"]').attributes('href')
    ).toBe(`${window.location.origin}/demo/token123`);
  });

  it('prefers the demo slug over the website token in the demo link', async () => {
    mocks.inboxes = ref([widgetInbox({ demo_slug: 'ask-acme' })]);
    const wrapper = mountPicker();
    await flushPromises();
    await wrapper.setProps({
      modelValue: widgetInbox({ demo_slug: 'ask-acme' }),
    });

    expect(
      wrapper.get('[data-test="playground-demo-link"]').attributes('href')
    ).toBe(`${window.location.origin}/demo/ask-acme`);
  });
});

import { flushPromises, mount } from '@vue/test-utils';
import { ref } from 'vue';
import AssistantWidgetTest from './AssistantWidgetTest.vue';

const dispatch = vi.fn();
const inboxes = ref([]);

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables/store.js', () => ({
  useStore: () => ({ dispatch }),
  useMapGetter: () => inboxes,
  useFunctionGetter: () => ref({ name: 'Mila' }),
}));
vi.mock('dashboard/composables/usePolicy', () => ({
  usePolicy: () => ({ isFeatureFlagEnabled: () => false }),
}));
vi.mock('./usePlaygroundSession', () => ({
  usePlaygroundSession: () => ({ initialize: vi.fn(), hasOverrides: false }),
}));

const widgetInbox = {
  id: 7,
  name: 'Acme Support',
  channel_type: 'Channel::WebWidget',
};

const mountScreen = () =>
  mount(AssistantWidgetTest, {
    props: { assistantId: 4 },
    global: {
      stubs: {
        WidgetLivePreview: {
          props: ['inboxId'],
          template: '<div data-test="widget">{{ inboxId }}</div>',
        },
        FixAnswerPanel: true,
        SidePanel: true,
        Select: true,
        Spinner: { template: '<div data-test="loading" />' },
        EmptyState: {
          props: ['title'],
          template: '<div data-test="empty">{{ title }}<slot /></div>',
        },
        NextButton: { template: '<button><slot /></button>' },
        RouterLink: { template: '<a><slot /></a>' },
      },
    },
  });

describe('AssistantWidgetTest', () => {
  beforeEach(() => {
    dispatch.mockReset();
    inboxes.value = [];
  });

  it('shows a spinner while the connected chats load', () => {
    dispatch.mockReturnValue(new Promise(() => {}));

    expect(mountScreen().find('[data-test="loading"]').exists()).toBe(true);
  });

  it('says when the chats could not be loaded', async () => {
    dispatch.mockRejectedValue(new Error('offline'));
    const wrapper = mountScreen();
    await flushPromises();

    expect(wrapper.find('[data-test="empty"]').text()).toContain(
      'CAPTAIN.PLAYGROUND.WIDGET_TEST.LOAD_ERROR'
    );
  });

  it('asks to connect a website chat when the AI agent has none', async () => {
    dispatch.mockResolvedValue();
    inboxes.value = [{ id: 2, name: 'Email', channel_type: 'Channel::Email' }];
    const wrapper = mountScreen();
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('captainInboxes/get', {
      assistantId: 4,
    });
    expect(wrapper.find('[data-test="empty"]').text()).toContain(
      'CAPTAIN.PLAYGROUND.WIDGET_TEST.NO_WIDGET.TITLE'
    );
  });

  it('shows the real widget of the connected website chat next to the explanations', async () => {
    dispatch.mockResolvedValue();
    inboxes.value = [widgetInbox];
    const wrapper = mountScreen();
    await flushPromises();

    expect(wrapper.find('[data-test="widget"]').text()).toBe('7');
    expect(wrapper.text()).toContain(
      'CAPTAIN.PLAYGROUND.WIDGET_TEST.WHY.EMPTY'
    );
    expect(wrapper.text()).toContain(
      'CAPTAIN.PLAYGROUND.WIDGET_TEST.NOT_COUNTED'
    );
  });
});

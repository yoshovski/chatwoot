import { flushPromises, mount } from '@vue/test-utils';
import { ref } from 'vue';
import GuidedSetup from './GuidedSetup.vue';

const route = { params: {} };
const router = { replace: vi.fn(), push: vi.fn() };
const uiSettings = ref({});
const updateUISettings = vi.fn(settings => {
  uiSettings.value = { ...uiSettings.value, ...settings };
});
const guided = {
  state: null,
  setup: {},
  progress: { phase: 'idle' },
  isLoading: false,
  loadError: false,
  assistantId: null,
  load: vi.fn(),
  stopPolling: vi.fn(),
};

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('vue-router', () => ({
  useRoute: () => route,
  useRouter: () => router,
}));
vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({ uiSettings, updateUISettings }),
}));
vi.mock('./useGuidedSetup', () => ({ useGuidedSetup: () => guided }));

const Step = name => ({
  name,
  props: ['guided'],
  template: `<div>${name}</div>`,
});

const render = () =>
  mount(GuidedSetup, {
    global: {
      mocks: { $t: key => key },
      stubs: {
        WebsiteStep: Step('WebsiteStep'),
        TestStep: Step('TestStep'),
        GoLiveStep: Step('GoLiveStep'),
        InstallStep: Step('InstallStep'),
        Icon: true,
        Spinner: true,
        Button: {
          props: ['label', 'disabled'],
          emits: ['click'],
          template:
            '<button :data-label="label" :disabled="disabled" @click="$emit(\'click\')">{{ label }}</button>',
        },
      },
    },
  });

const button = (wrapper, label) =>
  wrapper.find(`button[data-label="${label}"]`);

describe('GuidedSetup', () => {
  beforeEach(() => {
    route.params = {};
    uiSettings.value = {};
    Object.assign(guided, {
      state: null,
      setup: {},
      progress: { phase: 'idle' },
      assistantId: null,
    });
    vi.clearAllMocks();
  });

  it('opens the first open step and waits for the website import', async () => {
    const wrapper = render();
    await flushPromises();

    expect(guided.load).toHaveBeenCalled();
    expect(wrapper.text()).toContain('WebsiteStep');
    expect(button(wrapper, 'HOME.GUIDED.CONTINUE').attributes()).toHaveProperty(
      'disabled'
    );
  });

  it('skips a step for now and moves on', async () => {
    const wrapper = render();
    await button(wrapper, 'HOME.GUIDED.SKIP').trigger('click');

    expect(updateUISettings).toHaveBeenCalledWith({
      home_setup_skipped: ['knowledge'],
    });
    expect(router.replace).toHaveBeenCalledWith({
      name: 'account_home_setup',
      params: { step: 'test_agent' },
    });
  });

  it('remembers a finished test and opens the next step', async () => {
    route.params = { step: 'test_agent' };
    guided.assistantId = 4;
    const wrapper = render();
    await button(wrapper, 'HOME.GUIDED.CONTINUE').trigger('click');

    expect(updateUISettings).toHaveBeenCalledWith({
      home_setup_finished: ['test_agent'],
    });
    expect(router.replace).toHaveBeenCalledWith({
      name: 'account_home_setup',
      params: { step: 'agent_inbox' },
    });
  });

  it('finishes on the last step and returns to Home', async () => {
    route.params = { step: 'chat_widget' };
    const wrapper = render();
    await button(wrapper, 'HOME.GUIDED.FINISH').trigger('click');

    expect(router.push).toHaveBeenCalledWith({ name: 'account_home' });
  });

  it('hides Skip for a step that is already done', () => {
    route.params = { step: 'agent_inbox' };
    guided.setup = { agent_inbox: true };
    guided.state = { agent_live: true };
    const wrapper = render();

    expect(button(wrapper, 'HOME.GUIDED.SKIP').exists()).toBe(false);
    expect(
      button(wrapper, 'HOME.GUIDED.CONTINUE').attributes('disabled')
    ).toBeUndefined();
  });
});

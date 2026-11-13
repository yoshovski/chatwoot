import { flushPromises, mount } from '@vue/test-utils';
import { ref } from 'vue';
import GuidedSetup from './GuidedSetup.vue';
import { closeAccountOnboarding } from './accountOnboarding';

const route = { params: { accountId: '1' } };
const router = { replace: vi.fn(), push: vi.fn() };
const store = { dispatch: vi.fn() };
const currentUser = ref({ accounts: [] });
const uiSettings = ref({});
const updateUISettings = vi.fn(settings => {
  uiSettings.value = { ...uiSettings.value, ...settings };
});
const websiteSubmit = vi.fn();
const guided = {};

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('vue-router', () => ({
  useRoute: () => route,
  useRouter: () => router,
}));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => store,
  useMapGetter: () => currentUser,
}));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ currentAccount: ref({}) }),
}));
vi.mock('dashboard/composables/useConfig', () => ({
  useConfig: () => ({ enabledLanguages: [] }),
}));
vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({ uiSettings, updateUISettings }),
}));
vi.mock('./useGuidedSetup', () => ({ useGuidedSetup: () => guided }));
vi.mock('./useSetupChat', () => ({
  useSetupChat: () => ({ messages: [], isSending: false, ask: vi.fn() }),
}));
vi.mock('./accountOnboarding', async importOriginal => ({
  ...(await importOriginal()),
  closeAccountOnboarding: vi.fn(),
}));

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
        WebsiteStep: {
          props: ['guided'],
          setup(_, { expose }) {
            expose({ submit: websiteSubmit });
          },
          template: '<div>WebsiteStep</div>',
        },
        TestStep: Step('TestStep'),
        GoLiveStep: Step('GoLiveStep'),
        InstallStep: Step('InstallStep'),
        SetupChat: true,
        LearnedBanner: true,
        AuthLogo: true,
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
    route.params = { accountId: '1' };
    uiSettings.value = {};
    currentUser.value = { accounts: [{ id: 1 }] };
    Object.assign(guided, {
      state: null,
      setup: {},
      progress: { phase: 'idle' },
      isLoading: false,
      loadError: false,
      assistantId: null,
      learned: 0,
      total: 0,
      load: vi.fn(),
      stopPolling: vi.fn(),
      goLive: vi.fn(),
    });
    vi.clearAllMocks();
    websiteSubmit.mockResolvedValue(true);
  });

  it('opens the first open step without waiting for the website import', async () => {
    guided.progress = { phase: 'finding' };
    guided.state = { website_source: { id: 1 } };
    const wrapper = render();
    await flushPromises();

    expect(guided.load).toHaveBeenCalled();
    expect(wrapper.text()).toContain('WebsiteStep');
    expect(
      button(wrapper, 'HOME.GUIDED.CONTINUE').attributes('disabled')
    ).toBeUndefined();
  });

  it('starts the import from the website step and moves on', async () => {
    const wrapper = render();
    await button(wrapper, 'HOME.GUIDED.CONTINUE').trigger('click');
    await flushPromises();

    expect(websiteSubmit).toHaveBeenCalled();
    expect(router.replace).toHaveBeenCalledWith({
      name: 'account_home_setup',
      params: { step: 'test_agent' },
    });
  });

  it('stays on the website step when the address is refused', async () => {
    websiteSubmit.mockResolvedValue(false);
    const wrapper = render();
    await button(wrapper, 'HOME.GUIDED.CONTINUE').trigger('click');
    await flushPromises();

    expect(router.replace).not.toHaveBeenCalled();
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
    route.params.step = 'test_agent';
    guided.assistantId = 4;
    const wrapper = render();
    await button(wrapper, 'HOME.GUIDED.CONTINUE').trigger('click');
    await flushPromises();

    expect(updateUISettings).toHaveBeenCalledWith({
      home_setup_finished: ['test_agent'],
    });
    expect(router.replace).toHaveBeenCalledWith({
      name: 'account_home_setup',
      params: { step: 'agent_inbox' },
    });
  });

  it('turns the agent on from the go live step, or stays with the error', async () => {
    route.params.step = 'agent_inbox';
    guided.state = { readiness: 'importing', agent_live: false };
    guided.goLive.mockResolvedValueOnce({ ok: false, error: 'Not ready' });
    const wrapper = render();

    await button(wrapper, 'HOME.GUIDED.LIVE.TURN_ON').trigger('click');
    await flushPromises();
    expect(wrapper.find('[role="alert"]').text()).toBe('Not ready');
    expect(router.replace).not.toHaveBeenCalled();

    guided.goLive.mockResolvedValueOnce({ ok: true });
    await button(wrapper, 'HOME.GUIDED.LIVE.TURN_ON').trigger('click');
    await flushPromises();
    expect(router.replace).toHaveBeenCalledWith({
      name: 'account_home_setup',
      params: { step: 'chat_widget' },
    });
  });

  it('finishes on the last step and returns to Home', async () => {
    route.params.step = 'chat_widget';
    const wrapper = render();
    await button(wrapper, 'HOME.GUIDED.FINISH').trigger('click');
    await flushPromises();

    expect(router.push).toHaveBeenCalledWith({ name: 'account_home' });
  });

  it('hides Skip for a step that is already done', () => {
    route.params.step = 'agent_inbox';
    guided.setup = { agent_inbox: true };
    guided.state = { agent_live: true };
    const wrapper = render();

    expect(button(wrapper, 'HOME.GUIDED.SKIP').exists()).toBe(false);
    expect(
      button(wrapper, 'HOME.GUIDED.CONTINUE').attributes('disabled')
    ).toBeUndefined();
  });

  it('closes the upstream onboarding of a new account', async () => {
    currentUser.value = {
      accounts: [{ id: 1, onboarding_step: 'account_details' }],
    };
    render();
    await flushPromises();

    expect(closeAccountOnboarding).toHaveBeenCalledWith({
      step: 'account_details',
      languages: [],
    });
    expect(store.dispatch).toHaveBeenCalledWith('setUser');
  });

  it('leaves an account without open onboarding alone', async () => {
    render();
    await flushPromises();

    expect(closeAccountOnboarding).not.toHaveBeenCalled();
  });
});

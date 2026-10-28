import { flushPromises, mount } from '@vue/test-utils';
import { defineComponent, ref } from 'vue';
import GuidedSetupAPI from 'dashboard/api/captain/guidedSetup';
import { useGuidedSetupAutoOpen } from './useGuidedSetupAutoOpen';

const route = { name: 'home' };
const router = { push: vi.fn() };
const isAdmin = ref(true);
const uiSettings = ref({});
const updateUISettings = vi.fn();

vi.mock('vue-router', () => ({
  useRoute: () => route,
  useRouter: () => router,
}));
vi.mock('dashboard/composables/useAdmin', () => ({
  useAdmin: () => ({ isAdmin }),
}));
vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({ uiSettings, updateUISettings }),
}));
vi.mock('dashboard/api/captain/guidedSetup', () => ({
  default: { get: vi.fn() },
}));

const run = async () => {
  mount(
    defineComponent({
      setup: () => useGuidedSetupAutoOpen(),
      template: '<div />',
    })
  );
  await flushPromises();
};

describe('useGuidedSetupAutoOpen', () => {
  beforeEach(() => {
    route.name = 'home';
    isAdmin.value = true;
    uiSettings.value = {};
  });

  it('opens the guided setup once for a workspace without an AI agent', async () => {
    GuidedSetupAPI.get.mockResolvedValue({ data: { assistant_id: null } });
    await run();

    expect(updateUISettings).toHaveBeenCalledWith({ guided_setup_shown: true });
    expect(router.push).toHaveBeenCalledWith({ name: 'account_home_setup' });
  });

  it('only remembers it when an AI agent exists', async () => {
    GuidedSetupAPI.get.mockResolvedValue({ data: { assistant_id: 2 } });
    await run();

    expect(updateUISettings).toHaveBeenCalledWith({ guided_setup_shown: true });
    expect(router.push).not.toHaveBeenCalled();
  });

  it('does nothing for agents or when it was shown before', async () => {
    isAdmin.value = false;
    await run();
    isAdmin.value = true;
    uiSettings.value = { guided_setup_shown: true };
    await run();

    expect(GuidedSetupAPI.get).not.toHaveBeenCalled();
  });
});

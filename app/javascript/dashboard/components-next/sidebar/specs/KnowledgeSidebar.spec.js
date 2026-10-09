import { shallowMount } from '@vue/test-utils';
import { ref } from 'vue';
import Sidebar from '../Sidebar.vue';

const mocks = vi.hoisted(() => ({
  route: { name: 'captain_assistants_documents_index', path: '/', params: {} },
}));

vi.mock('vue-router', () => ({
  useRoute: () => mocks.route,
  useRouter: () => ({ resolve: () => ({ href: '/' }) }),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('vuex', () => ({
  useStore: () => ({
    dispatch: vi.fn(),
    getters: {},
  }),
}));

vi.mock('dashboard/helpers/routeHelpers', () => ({
  accountScopedRoute: (name, params, query) => ({ name, params, query }),
}));

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    accountId: { value: 1 },
    account: { value: {} },
    customAttributes: { value: [] },
    isFeatureEnabledonAccount: { value: () => false },
    accountScopedRoute: (name, params, query) => ({ name, params, query }),
    isOnChatwootCloud: { value: false },
  }),
}));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({
    dispatch: vi.fn(),
    getters: {},
  }),
  useMapGetter: key => {
    if (key === 'accounts/isFeatureEnabledonAccount') {
      return ref(() => false);
    }
    if (key === 'getCurrentAccountId') {
      return ref(1);
    }
    if (key.includes('Sort') || key.includes('sort')) {
      return ref(() => null);
    }
    return ref([]);
  },
}));

vi.mock('dashboard/composables/usePolicy', () => ({
  usePolicy: () => ({
    checkPermissions: () => true,
    shouldShow: () => true,
  }),
}));

vi.mock('../provider', () => ({
  provideSidebarContext: vi.fn(),
  providePopoverState: vi.fn(),
  useSidebarResize: () => ({
    sidebarWidth: ref(200),
    isCollapsed: ref(false),
    snapToCollapsed: vi.fn(),
    snapToExpanded: vi.fn(),
    COLLAPSED_THRESHOLD: 160,
  }),
}));

describe('Sidebar Knowledge Navigation', () => {
  it('configures Knowledge item to be active on all four knowledge routes', () => {
    const wrapper = shallowMount(Sidebar, {
      global: {
        stubs: {
          RouterLink: true,
          SidebarGroup: {
            props: ['name', 'label', 'children', 'activeOn'],
            template: '<div />',
          },
        },
      },
    });
    const vm = wrapper.vm;
    // Find the Captain navigation section
    const captainItem = vm.menuItems.find(item => item.name === 'Captain');
    expect(captainItem).toBeDefined();

    const knowledgeItem = captainItem.children.find(
      child => child.name === 'Knowledge'
    );
    expect(knowledgeItem).toBeDefined();

    const expectedActiveRoutes = [
      'captain_assistants_documents_index',
      'captain_assistants_responses_index',
      'captain_assistants_faq_suggestions',
      'captain_assistants_products_index',
    ];

    expect(knowledgeItem.activeOn).toEqual(expectedActiveRoutes);
  });
});

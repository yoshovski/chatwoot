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
    currentAccount: { value: { id: 1 } },
    isCloudFeatureEnabled: () => false,
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
  it('shows one entry per agent section with Knowledge active on its tabs', () => {
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

    // One flat entry per section; Actions needs the custom tools feature.
    expect(captainItem.children.map(child => child.name)).toEqual([
      'captain_section_overview',
      'captain_section_profile',
      'captain_section_knowledge',
      'captain_section_behavior',
      'captain_section_handoff',
      'captain_section_scenarios',
      'captain_section_channels',
    ]);

    const knowledgeItem = captainItem.children.find(
      child => child.name === 'captain_section_knowledge'
    );
    expect(knowledgeItem.to).toEqual({
      name: 'captain_assistants_index',
      params: { navigationPath: 'captain_assistants_documents_index' },
      query: undefined,
    });
    // Products only appears with a connected Shopify store.
    expect(knowledgeItem.activeOn).toEqual([
      'captain_assistants_documents_index',
      'captain_assistants_responses_index',
      'captain_assistants_faq_suggestions',
    ]);
  });
});

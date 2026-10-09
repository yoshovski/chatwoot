import { shallowMount, flushPromises } from '@vue/test-utils';
import KnowledgeHeader from './KnowledgeHeader.vue';

const { getFaqStats, getStatus, getCatalogProducts, push, route } = vi.hoisted(
  () => ({
    getFaqStats: vi.fn(),
    getStatus: vi.fn(),
    getCatalogProducts: vi.fn(),
    push: vi.fn(),
    route: {
      name: 'captain_assistants_documents_index',
      params: { accountId: '1', assistantId: '2' },
    },
  })
);

vi.mock('dashboard/api/captain/assistant', () => ({
  default: { getFaqStats },
}));

vi.mock('dashboard/api/integrations/shopify', () => ({
  default: { getStatus, getCatalogProducts },
}));

vi.mock('vue-router', () => ({
  useRoute: () => route,
  useRouter: () => ({ push }),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, options = {}) => {
      if (options.count !== undefined) return `${options.count} ${key}`;
      return key;
    },
  }),
}));

const TabBarStub = {
  name: 'TabBar',
  props: ['tabs', 'initialActiveTab'],
  emits: ['tabChanged'],
  template: '<div class="tab-bar-stub"><slot /></div>',
};

const mountHeader = (props = {}) =>
  shallowMount(KnowledgeHeader, {
    props,
    global: {
      stubs: {
        TabBar: TabBarStub,
      },
      mocks: {
        $t: (key, options = {}) => {
          if (options.count !== undefined) return `${options.count} ${key}`;
          return key;
        },
      },
    },
  });

describe('KnowledgeHeader', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    route.name = 'captain_assistants_documents_index';
    route.params = { accountId: '1', assistantId: '2' };
    getFaqStats.mockResolvedValue({
      data: { documents: 5, approved: 14, suggestions: 2 },
    });
    getStatus.mockResolvedValue({
      data: { hook: { state: 'connected', catalog_status: 'on' } },
    });
    getCatalogProducts.mockResolvedValue({
      data: { counts: { synced: 42 } },
    });
  });

  it('renders title, subtitle and fetches stats on mount', async () => {
    const wrapper = mountHeader();
    await flushPromises();

    expect(wrapper.text()).toContain('CAPTAIN.KNOWLEDGE.TITLE');
    expect(wrapper.text()).toContain('CAPTAIN.KNOWLEDGE.SUBTITLE');
    expect(getFaqStats).toHaveBeenCalledWith({ assistantId: 2 });
    expect(wrapper.text()).toContain('5 CAPTAIN.KNOWLEDGE.STATS.SOURCES');
    expect(wrapper.text()).toContain('14 CAPTAIN.KNOWLEDGE.STATS.FAQS');
    expect(wrapper.text()).toContain('42 CAPTAIN.KNOWLEDGE.STATS.PRODUCTS');
  });

  it('includes Products tab when Shopify is connected', async () => {
    const wrapper = mountHeader();
    await flushPromises();

    const tabBar = wrapper.findComponent(TabBarStub);
    const tabs = tabBar.props('tabs');
    expect(tabs.map(t => t.key)).toEqual(['sources', 'faqs', 'products']);
    expect(tabs.find(t => t.key === 'faqs').count).toBe(2);
  });

  it('excludes Products tab when Shopify is not connected', async () => {
    getStatus.mockResolvedValue({
      data: { hook: null },
    });
    const wrapper = mountHeader();
    await flushPromises();

    const tabBar = wrapper.findComponent(TabBarStub);
    const tabs = tabBar.props('tabs');
    expect(tabs.map(t => t.key)).toEqual(['sources', 'faqs']);
  });

  it('routes to the clicked tab', async () => {
    const wrapper = mountHeader();
    await flushPromises();

    const tabBar = wrapper.findComponent(TabBarStub);
    await tabBar.vm.$emit('tabChanged', { key: 'faqs' });

    expect(push).toHaveBeenCalledWith({
      name: 'captain_assistants_responses_index',
      params: { accountId: '1', assistantId: '2' },
    });
  });
});

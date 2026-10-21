import { shallowMount, flushPromises } from '@vue/test-utils';
import KnowledgeHeader from './KnowledgeHeader.vue';

const { getFaqStats, getStatus } = vi.hoisted(() => ({
  getFaqStats: vi.fn(),
  getStatus: vi.fn(),
}));
vi.mock('dashboard/api/captain/assistant', () => ({
  default: { getFaqStats },
}));
vi.mock('dashboard/api/integrations/shopify', () => ({
  default: { getStatus },
}));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { assistantId: '2' } }),
}));
const mountHeader = props =>
  shallowMount(KnowledgeHeader, {
    props,
    global: {
      mocks: { $t: (key, options = {}) => `${options.count ?? ''} ${key}` },
    },
  });

describe('KnowledgeHeader', () => {
  beforeEach(() =>
    getFaqStats.mockResolvedValue({ data: { documents: 5, approved: 14 } })
  );

  it('shows knowledge counts without a second navigation system or Shopify requests', async () => {
    const wrapper = mountHeader();
    await flushPromises();
    expect(wrapper.text()).toContain('5 CAPTAIN.KNOWLEDGE.STATS.SOURCES');
    expect(wrapper.text()).toContain('14 CAPTAIN.KNOWLEDGE.STATS.FAQS');
    expect(wrapper.find('[role="tablist"]').exists()).toBe(false);
    expect(wrapper.findComponent({ name: 'TabBar' }).exists()).toBe(false);
    expect(getStatus).not.toHaveBeenCalled();
  });

  it('uses supplied counts without fetching them again', async () => {
    const wrapper = mountHeader({ faqStats: { documents: 3, approved: 8 } });
    await flushPromises();
    expect(getFaqStats).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('3 CAPTAIN.KNOWLEDGE.STATS.SOURCES');
  });
});

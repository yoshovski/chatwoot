import { shallowMount, flushPromises } from '@vue/test-utils';
import KnowledgeBriefPanel from './KnowledgeBriefPanel.vue';

const { brief } = vi.hoisted(() => ({ brief: vi.fn() }));

vi.mock('dashboard/api/captain/knowledgeSources', () => ({
  default: { brief, generateBrief: vi.fn(), publishBrief: vi.fn() },
}));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const ButtonStub = {
  props: ['label', 'disabled'],
  emits: ['click'],
  template:
    '<button type="button" :data-label="label" @click="$emit(\'click\')">{{ label }}</button>',
};

const sources = [
  {
    id: 1,
    name: 'About us',
    url: 'https://example.com/about',
    section: 'example.com/about',
  },
  {
    id: 2,
    name: 'Refunds',
    url: 'https://help.example.com/articles/2',
    section: 'help.example.com/articles',
  },
  {
    id: 3,
    name: 'Login help',
    url: 'https://help.example.com/articles/3',
    section: 'help.example.com/articles',
  },
];

const mountPanel = () =>
  shallowMount(KnowledgeBriefPanel, {
    props: { assistantId: 4 },
    global: {
      mocks: { $t: key => key },
      stubs: { Button: ButtonStub, Checkbox: true, Input: true },
    },
  });

describe('KnowledgeBriefPanel source picker', () => {
  beforeEach(() => {
    brief.mockResolvedValue({
      data: {
        status: 'ready',
        enabled: false,
        sources,
        draft: {
          overview: { text: 'Overview', document_ids: [1] },
          topics: [],
          offerings: [
            {
              id: 'core',
              name: 'Cleeng Core',
              kind: 'product',
              purpose: 'Subscriber entitlement management.',
              status: 'auto',
              evidence: [
                {
                  document_id: 1,
                  passage_id: 'p0',
                  quote: 'Cleeng Core manages entitlements.',
                },
              ],
            },
          ],
          document_ids: [1],
          source_reasons: { 1: 'Company overview' },
        },
        coverage: {
          eligible: 3,
          processed: 2,
          partial: 0,
          pending: 1,
          failed: 0,
          discovered_pages: 10,
          budget_stopped: true,
        },
        published: {},
      },
    });
  });

  it('lists suggested sources first with their reason, then the rest by section', async () => {
    const wrapper = mountPanel();
    await flushPromises();
    await wrapper
      .get('[data-label="CAPTAIN.KNOWLEDGE_BRIEF.CHOOSE_SOURCES"]')
      .trigger('click');

    const text = wrapper.text();
    expect(
      text.indexOf('CAPTAIN.KNOWLEDGE_BRIEF.SUGGESTED_SOURCES')
    ).toBeLessThan(text.indexOf('help.example.com/articles'));
    expect(text).toContain('Company overview');
    expect(text.indexOf('About us')).toBeLessThan(text.indexOf('Refunds'));
  });

  it('renders coverage metrics and allows reviewing or rejecting extracted offerings', async () => {
    const wrapper = mountPanel();
    await flushPromises();

    expect(wrapper.find('[data-test="brief-coverage"]').exists()).toBe(true);
    expect(wrapper.text()).toContain(
      'CAPTAIN.KNOWLEDGE_BRIEF.COVERAGE_BUDGET_STOPPED'
    );
    expect(wrapper.find('[data-test="offering-core"]').text()).toContain(
      'Cleeng Core'
    );
  });
});

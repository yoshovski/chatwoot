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
          document_ids: [1],
          source_reasons: { 1: 'Company overview' },
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
});

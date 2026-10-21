import { shallowMount, flushPromises } from '@vue/test-utils';
import KnowledgeSourceBrowser from './KnowledgeSourceBrowser.vue';

const { sections } = vi.hoisted(() => ({ sections: vi.fn() }));
vi.mock('dashboard/api/captain/knowledgeSources', () => ({
  default: { sections },
}));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
const mountBrowser = props =>
  shallowMount(KnowledgeSourceBrowser, {
    props: { assistantId: 2, ...props },
    global: {
      stubs: {
        Button: { props: ['label'], template: '<button>{{ label }}</button>' },
      },
    },
  });

describe('KnowledgeSourceBrowser', () => {
  beforeEach(() =>
    sections.mockResolvedValue({
      data: {
        sections: [
          { key: 'example.com/resources', count: 2, failed: 1 },
          { key: 'example.com/solutions', count: 1, failed: 0 },
          { key: 'support.example.com/articles', count: 3, failed: 0 },
        ],
      },
    })
  );

  it('groups by exact host and opens pages without selecting them for a bulk action', async () => {
    const wrapper = mountBrowser();
    await flushPromises();
    expect(wrapper.findAll('li')).toHaveLength(2);
    expect(wrapper.find('input[type="checkbox"]').exists()).toBe(false);
    const manage = wrapper
      .findAll('button')
      .find(button => button.text() === 'PLATFORM_NAV.MANAGE_PAGES');
    await manage.trigger('click');
    expect(wrapper.emitted('update:website').at(-1)).toEqual(['example.com']);
  });

  it('offers only folders belonging to the opened website', async () => {
    const wrapper = mountBrowser({ website: 'example.com' });
    await flushPromises();
    expect(wrapper.findAll('option')).toHaveLength(3);
    await wrapper.find('select').setValue('example.com/solutions');
    expect(wrapper.emitted('update:section').at(-1)).toEqual([
      'example.com/solutions',
    ]);
    expect(wrapper.html()).not.toContain('support.example.com/articles');
  });
});

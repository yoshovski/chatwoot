import { shallowMount, flushPromises } from '@vue/test-utils';
import KnowledgeSourceBrowser from './KnowledgeSourceBrowser.vue';

const { sections, list } = vi.hoisted(() => ({
  sections: vi.fn(),
  list: vi.fn(),
}));
vi.mock('dashboard/api/captain/knowledgeSources', () => ({
  default: { sections, list },
}));
vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) =>
      params?.host ? `${params.host} (${params.count})` : key,
  }),
}));
const mountBrowser = props =>
  shallowMount(KnowledgeSourceBrowser, {
    props: { assistantId: 2, canManage: true, ...props },
    global: {
      directives: { tooltip: {} },
      stubs: {
        Button: {
          props: ['label'],
          emits: ['click'],
          template:
            '<button @click="$emit(\'click\')">{{ label }}<slot /></button>',
        },
        DropdownMenu: {
          name: 'DropdownMenu',
          props: ['menuSections', 'menuItems'],
          template: '<div data-test="menu" />',
        },
      },
    },
  });

describe('KnowledgeSourceBrowser', () => {
  beforeEach(() => {
    sections.mockResolvedValue({
      data: {
        sections: [
          { key: 'example.com/resources', count: 2 },
          { key: 'example.com/solutions', count: 1 },
          { key: 'support.example.com/articles', count: 3 },
          { key: 'files/pdf', count: 4 },
        ],
      },
    });
    list.mockResolvedValue({
      data: [
        {
          id: 7,
          url: 'https://example.com',
          status: 'ready',
          selected_urls: ['https://example.com/a'],
        },
      ],
    });
  });

  it('lists each website once with its page count in the source menu', async () => {
    const wrapper = mountBrowser();
    await flushPromises();
    await wrapper.find('button').trigger('click');
    const menu = wrapper.findComponent({ name: 'DropdownMenu' });
    const websites = menu
      .props('menuSections')[1]
      .items.map(item => item.label);
    expect(websites).toEqual(['example.com (3)', 'support.example.com (3)']);
  });

  it('shows Manage pages for the chosen website', async () => {
    const wrapper = mountBrowser({ source: 'example.com' });
    await flushPromises();
    const manage = wrapper
      .findAll('button')
      .find(button => button.text() === 'PLATFORM_NAV.MANAGE_PAGES');
    await manage.trigger('click');
    expect(wrapper.emitted('manage')[0][0].id).toBe(7);
  });

  it('opens the only website from Manage website pages, without a filter', async () => {
    const wrapper = mountBrowser();
    await flushPromises();
    const manage = wrapper
      .findAll('button')
      .find(button => button.text() === 'PLATFORM_NAV.MANAGE_WEBSITES');
    await manage.trigger('click');
    expect(wrapper.emitted('manage')[0][0].id).toBe(7);
  });

  it('lets the administrator pick one of several websites', async () => {
    list.mockResolvedValue({
      data: [
        {
          id: 7,
          url: 'https://example.com',
          status: 'ready',
          selected_urls: [],
        },
        {
          id: 8,
          url: 'https://docs.example.org',
          status: 'discovering',
          selected_urls: [],
        },
      ],
    });
    const wrapper = mountBrowser();
    await flushPromises();
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'PLATFORM_NAV.MANAGE_WEBSITES')
      .trigger('click');
    const menu = wrapper.findComponent({ name: 'DropdownMenu' });
    expect(menu.props('menuItems').map(item => item.value)).toEqual([7, 8]);
    menu.vm.$emit('action', { value: 8 });
    expect(wrapper.emitted('manage')[0][0].id).toBe(8);
  });
});

import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createI18n } from 'vue-i18n';
import en from 'dashboard/i18n/locale/en';
import ToolPalette from './ToolPalette.vue';

vi.mock('vue-router', () => ({ useRoute: () => ({ params: {} }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

Element.prototype.scrollIntoView = () => {};

const i18n = createI18n({ legacy: false, locale: 'en', messages: { en } });
const tools = [
  { id: 'faq_lookup', title: 'Search knowledge' },
  {
    id: 'update_contact_attribute',
    title: 'Update contact attribute',
    built_in_action: true,
  },
  { id: 'custom_quote', title: 'Get a quote', custom: true },
  { id: 'crm_lookup', title: 'CRM lookup', mcp: true },
];

const store = createStore({
  modules: {
    captainTools: { namespaced: true, getters: { getRecords: () => tools } },
    attributes: {
      namespaced: true,
      getters: {
        getContactAttributes: () => [
          {
            attributeKey: 'company_size',
            attributeDisplayName: 'Company size',
          },
        ],
        getAttributesByModel: () => () => [],
        getAttributes: () => [],
      },
      actions: { get: vi.fn() },
    },
    teams: {
      namespaced: true,
      getters: { getTeams: () => [] },
      actions: { get: vi.fn() },
    },
    agents: { namespaced: true, getters: { getAgents: () => [] } },
    captainAssistants: {
      namespaced: true,
      getters: { getRecord: () => () => null },
    },
  },
});

const openMenu = async () => {
  const wrapper = mount(ToolPalette, { global: { plugins: [store, i18n] } });
  await wrapper.find('[data-test="palette-more"]').trigger('click');
  return wrapper;
};

describe('ToolPalette', () => {
  it('groups the menu into built-in categories, your API, MCP, contact properties and reply shape', async () => {
    const wrapper = await openMenu();

    expect(wrapper.text()).toContain('Describe an action…');
    expect(wrapper.text()).toContain('Find answers');
    expect(wrapper.text()).toContain('Customer details');
    expect(wrapper.text()).toContain('Your API');
    expect(wrapper.text()).toContain('From MCP servers');
    expect(wrapper.text()).toContain('Contact properties');
    expect(wrapper.text()).toContain('Read Company size');
    expect(wrapper.text()).toContain('Update Company size');
    expect(wrapper.text()).toContain('Send as a separate message');
  });

  it('inserts text for Read and reply shape, and plain tools directly', async () => {
    const wrapper = await openMenu();
    const click = async title => {
      const item = wrapper
        .findAll('[id^="tool-item-"]')
        .find(element => element.text().includes(title));
      await item.trigger('click');
      await wrapper.find('[data-test="palette-more"]').trigger('click');
    };

    await click('Read Company size');
    await click('Send as a separate message');
    await click('Get a quote');
    await flushPromises();

    expect(wrapper.emitted('insertText')).toEqual([
      ["the contact's Company size (company_size)"],
      ['Send this as a separate message.'],
    ]);
    expect(wrapper.emitted('insertTool')[0][0].id).toBe('custom_quote');
  });
});

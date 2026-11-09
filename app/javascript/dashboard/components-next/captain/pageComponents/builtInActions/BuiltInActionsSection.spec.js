import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import en from 'dashboard/i18n/locale/en';
import BuiltInActionsSection from './BuiltInActionsSection.vue';

const push = vi.fn();
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1', assistantId: '4' } }),
  useRouter: () => ({ push }),
}));
vi.mock('dashboard/composables/store', async () => {
  const { ref } = await import('vue');
  return {
    useStore: () => ({ dispatch: vi.fn() }),
    useMapGetter: () =>
      ref([
        { id: 'faq_lookup', title: 'Search knowledge', emoji: '📚' },
        { id: 'assign_team', title: 'Assign team', built_in_action: true },
        { id: 'custom_quote', title: 'Get a quote', custom: true },
        { id: 'crm_lookup', title: 'CRM lookup', mcp: true },
      ]),
  };
});

const i18n = createI18n({ legacy: false, locale: 'en', messages: { en } });

// The help opens in a side panel; render its content inline.
const SidePanel = {
  template: '<div><slot /></div>',
  methods: { open: vi.fn() },
};
const mountSection = () =>
  mount(BuiltInActionsSection, {
    global: { plugins: [i18n], stubs: { SidePanel } },
  });

describe('BuiltInActionsSection', () => {
  it('lists built-in actions by category and links to scenarios', async () => {
    const wrapper = mountSection();

    const cards = wrapper.findAll('[data-test="built-in-action-card"]');
    expect(cards.map(card => card.text())).toEqual([
      expect.stringContaining('Search knowledge'),
      expect.stringContaining('Assign team'),
    ]);
    const headings = wrapper.findAll('h3').map(heading => heading.text());
    expect(headings).toEqual(['Find answers', 'Conversation']);

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Use in a scenario')
      .trigger('click');
    expect(push).toHaveBeenCalledWith({
      name: 'captain_assistants_scenarios_index',
      params: { accountId: '1', assistantId: '4' },
    });
  });

  it('opens the decision table in a side panel', async () => {
    const wrapper = mountSection();

    await wrapper.find('[data-test="built-in-help-toggle"]').trigger('click');

    expect(SidePanel.methods.open).toHaveBeenCalled();
    expect(wrapper.find('[data-test="built-in-help"]').text()).toContain(
      'the AI must change something or fetch live data'
    );
  });
});

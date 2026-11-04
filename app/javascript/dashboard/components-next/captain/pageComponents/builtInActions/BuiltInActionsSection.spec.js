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

describe('BuiltInActionsSection', () => {
  it('shows one card per built-in action and links to scenarios', async () => {
    const wrapper = mount(BuiltInActionsSection, {
      global: { plugins: [i18n] },
    });

    const cards = wrapper.findAll('[data-test="built-in-action-card"]');
    expect(cards.map(card => card.text())).toEqual([
      expect.stringContaining('Search knowledge'),
      expect.stringContaining('Assign team'),
    ]);

    await cards[1].find('button').trigger('click');
    expect(push).toHaveBeenCalledWith({
      name: 'captain_assistants_scenarios_index',
      params: { accountId: '1', assistantId: '4' },
    });
  });

  it('opens the decision table', async () => {
    const wrapper = mount(BuiltInActionsSection, {
      global: { plugins: [i18n] },
    });

    await wrapper.find('[data-test="built-in-help-toggle"]').trigger('click');

    expect(wrapper.find('[data-test="built-in-help"]').text()).toContain(
      'the AI must change something or fetch live data'
    );
  });
});

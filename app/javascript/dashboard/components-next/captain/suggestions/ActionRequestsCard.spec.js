import { mount, RouterLinkStub } from '@vue/test-utils';
import ActionRequestsCard from './ActionRequestsCard.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) =>
      params ? `${key} ${params.count ?? params.text}` : key,
  }),
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: 1, assistantId: 4 } }),
}));

const mountCard = requests =>
  mount(ActionRequestsCard, {
    props: { requests },
    global: {
      mocks: { $t: key => key },
      stubs: { RouterLink: RouterLinkStub },
    },
  });

describe('ActionRequestsCard', () => {
  it('lists each intent with its count, an example and where to set it up', () => {
    const wrapper = mountCard([
      {
        intent: 'order_status',
        conversations_count: 9,
        examples: ['can you check where is my order'],
      },
      { intent: 'return', conversations_count: 4, examples: [] },
      { intent: 'booking', conversations_count: 2, examples: [] },
    ]);

    const rows = wrapper.findAll('li');
    expect(rows).toHaveLength(3);
    expect(rows[0].text()).toContain('INTENTS.ORDER_STATUS.TITLE');
    expect(rows[0].text()).toContain(
      'CAPTAIN.SUGGESTIONS.CONVERSATIONS 9 · CAPTAIN.SUGGESTIONS.ACTIONS.EXAMPLE can you check where is my order'
    );

    const links = wrapper.findAllComponents(RouterLinkStub);
    expect(links[0].props('to')).toEqual({
      name: 'captain_tools_connections',
      params: { accountId: 1, assistantId: 4 },
      query: {},
    });
    expect(links[1].props('to').query).toEqual({
      template: 'returns_and_warranty',
    });
    expect(links[2].props('to').query).toEqual({ template: 'book_a_call' });
  });

  it('sends an unknown intent to the scenarios page', () => {
    const wrapper = mountCard([{ intent: 'other', conversations_count: 1 }]);

    expect(wrapper.text()).toContain('INTENTS.OTHER.TITLE');
    expect(wrapper.findComponent(RouterLinkStub).props('to')).toEqual({
      name: 'captain_assistants_scenarios_index',
      params: { accountId: 1, assistantId: 4 },
      query: {},
    });
  });
});

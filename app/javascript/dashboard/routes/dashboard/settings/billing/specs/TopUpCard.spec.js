import { flushPromises, mount } from '@vue/test-utils';
import api from 'dashboard/api/accountSubscription';
import TopUpCard from '../components/TopUpCard.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
    locale: { value: 'en' },
  }),
}));
vi.mock('dashboard/api/accountSubscription', () => ({
  default: { topUp: vi.fn(), updateTopUpSettings: vi.fn() },
}));

const topUp = (overrides = {}) => ({
  available: true,
  pack: { conversations: 50, amount_cents: 800, currency: 'eur' },
  auto: {
    enabled: false,
    max_packs: 1,
    threshold: 5,
    used_this_period: 0,
    failed_at: null,
  },
  history: [],
  ...overrides,
});
const mountCard = (props = {}) =>
  mount(TopUpCard, { props: { topUp: topUp(), extraLeft: 0, ...props } });
const find = (wrapper, id) => wrapper.find(`[data-test-id="${id}"]`);

describe('TopUpCard', () => {
  beforeEach(() => vi.clearAllMocks());

  it('offers one pack at its price', () => {
    const wrapper = mountCard({ extraLeft: 12 });

    expect(wrapper.text()).toContain('TOP_UP.LEFT {"count":12}');
    expect(find(wrapper, 'top-up-buy').text()).toContain('"count":50');
    expect(find(wrapper, 'top-up-buy').text()).toContain('8.00');
  });

  it('says the conversations are on their way after a saved-card payment', async () => {
    api.topUp.mockResolvedValue({ data: { status: 'paid' } });
    const wrapper = mountCard();

    await find(wrapper, 'top-up-buy').trigger('click');
    await flushPromises();

    expect(api.topUp).toHaveBeenCalledWith(expect.any(String));
    expect(find(wrapper, 'top-up-notice').text()).toBe(
      'ACCOUNT_SUBSCRIPTION.TOP_UP.NOTICE.PAID'
    );
    expect(wrapper.emitted('refresh')).toBeTruthy();
  });

  it('sends the customer to Stripe for Checkout or 3-D Secure', async () => {
    const assign = vi.fn();
    vi.stubGlobal('location', { assign });
    api.topUp.mockResolvedValue({
      data: { status: 'checkout', url: 'https://checkout.stripe.test' },
    });
    const wrapper = mountCard();

    await find(wrapper, 'top-up-buy').trigger('click');
    await flushPromises();

    expect(assign).toHaveBeenCalledWith('https://checkout.stripe.test');
    vi.unstubAllGlobals();
  });

  it('says when the card is declined', async () => {
    api.topUp.mockRejectedValue({ response: { status: 422 } });
    const wrapper = mountCard();

    await find(wrapper, 'top-up-buy').trigger('click');
    await flushPromises();

    expect(find(wrapper, 'top-up-notice').attributes('role')).toBe('alert');
    expect(find(wrapper, 'top-up-notice').text()).toContain('DECLINED');
  });

  it('turns auto top-up on with the current ceiling', async () => {
    api.updateTopUpSettings.mockResolvedValue({ data: {} });
    const wrapper = mountCard();

    await find(wrapper, 'top-up-auto-switch').trigger('click');
    await flushPromises();

    expect(api.updateTopUpSettings).toHaveBeenCalledWith({
      auto_top_up_enabled: true,
      auto_top_up_max_packs: 1,
    });
  });

  it('explains that a failed payment switched auto top-up off', () => {
    const wrapper = mountCard({
      topUp: topUp({
        auto: { ...topUp().auto, failed_at: '2026-11-10T10:00:00Z' },
      }),
    });

    expect(find(wrapper, 'top-up-auto-failed').exists()).toBe(true);
  });

  it('lists the history without the buy button when packs are not for sale', () => {
    const wrapper = mountCard({
      topUp: topUp({
        available: false,
        history: [
          {
            id: 1,
            reason: 'purchase',
            amount: 50,
            remaining: 20,
            expires_at: '2027-11-10T10:00:00Z',
            created_at: '2026-11-10T10:00:00Z',
          },
          {
            id: 2,
            reason: 'expiry',
            amount: -5,
            remaining: null,
            expires_at: null,
            created_at: '2026-11-11T10:00:00Z',
          },
        ],
      }),
    });

    expect(find(wrapper, 'top-up-buy').exists()).toBe(false);
    const rows = wrapper.findAll('[data-test-id="top-up-history-row"]');
    expect(rows).toHaveLength(2);
    expect(rows[0].text()).toContain('HISTORY.PURCHASE {"count":50}');
    expect(rows[0].text()).toContain('HISTORY.REMAINING');
    expect(rows[1].text()).toContain('HISTORY.EXPIRY {"count":5}');
  });
});

import { mount, flushPromises } from '@vue/test-utils';
import api from 'dashboard/api/accountSubscription';
import AutoTopUpCard from '../components/AutoTopUpCard.vue';
import BillingAlert from '../components/BillingAlert.vue';
import InvoicesCard from '../components/InvoicesCard.vue';
import OverviewCard from '../components/OverviewCard.vue';
import PlanPickerDialog from '../components/PlanPickerDialog.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
    locale: { value: 'en' },
  }),
}));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountScopedRoute: name => ({ name }) }),
}));
vi.mock('dashboard/api/accountSubscription', () => ({
  default: { invoices: vi.fn(), updateTopUpSettings: vi.fn() },
}));

const DAY = 24 * 60 * 60 * 1000;
const at = days => new Date(Date.now() + days * DAY).toISOString();
const GROWTH = {
  id: 3,
  name: 'Growth',
  currency: 'eur',
  monthly_price_cents: 3900,
  annual_price_cents: 39000,
  ai_conversations_limit: 150,
  add_ons: [],
};
const PLANS = [
  {
    ...GROWTH,
    id: 2,
    name: 'Starter',
    monthly_price_cents: 1900,
    annual_price_cents: 19000,
  },
  GROWTH,
  {
    ...GROWTH,
    id: 4,
    name: 'Pro',
    monthly_price_cents: 7900,
    annual_price_cents: 79000,
  },
];

// The subscription JSON of a paying Growth account at 112 of 150, twelve days into its month.
const billing = (extra = {}) => ({
  enabled: true,
  currency: 'eur',
  billing_interval: 'month',
  monthly_price_cents: 0,
  plan: GROWTH,
  plans: PLANS,
  has_subscription: true,
  can_manage: true,
  can_change_plan: true,
  payment_status: 'active',
  period_ends_at: at(18),
  quota_started_at: at(-12),
  quota_resets_at: at(18),
  extra_left: 0,
  stripe_details: {
    amount_cents: 3900,
    currency: 'eur',
    quantity: 1,
    interval: 'month',
    card: { brand: 'visa', last4: '4242' },
  },
  products: {
    ai_conversations: { used: 112, limit: 150, period: 'month' },
  },
  top_up: {
    available: true,
    pack: { conversations: 50, amount_cents: 800, currency: 'eur' },
    auto: { enabled: false, max_packs: 2, failed_at: null },
    history: [],
  },
  ...extra,
});
const TRIAL = {
  trial_enabled: true,
  trial_ends_at: at(5),
  has_subscription: false,
  can_manage: false,
  can_change_plan: false,
  can_buy_plan: true,
  payment_status: 'trialing',
  stripe_details: {},
  products: { ai_conversations: { used: 31, limit: 50, period: 'trial' } },
};

const overview = (data, props = {}) =>
  mount(OverviewCard, {
    props: { billing: data, ...props },
    global: { stubs: { RouterLink: true } },
  });
const alertOf = data => mount(BillingAlert, { props: { billing: data } });

describe('OverviewCard', () => {
  it('shows a running plan without a badge, with its price, renewal and card', () => {
    const wrapper = overview(billing());

    expect(wrapper.text()).toContain('Growth');
    expect(wrapper.text()).toContain('€39');
    expect(wrapper.text()).toContain('BILLING_PAGE.RENEWS_ON');
    expect(wrapper.text()).toContain('BILLING_PAGE.CARD_ENDING');
    expect(wrapper.text()).toContain('BILLING_PAGE.CHANGE_PLAN');
    expect(wrapper.text()).not.toContain('BILLING_PAGE.STATUS');
  });

  it('shows days left and one call to choose a plan during the trial', () => {
    const wrapper = overview(billing(TRIAL));

    expect(wrapper.text()).toContain('BILLING_PAGE.STATUS.TRIAL {"count":5}');
    expect(wrapper.text()).toContain('BILLING_PAGE.TRIAL_THEN_FREE');
    expect(wrapper.text()).toContain('BILLING_PAGE.AI_IN_TRIAL');
    expect(
      wrapper
        .findAll('button')
        .filter(b => b.text() === 'BILLING_PAGE.CHOOSE_PLAN')
    ).toHaveLength(1);
  });

  it('marks a founder, shows the price actually charged and asks to contact us', async () => {
    const data = billing({ founder_plan: true, can_change_plan: false });
    data.stripe_details.amount_cents = 2500;
    const wrapper = overview(data);

    expect(wrapper.text()).toContain('BILLING_PAGE.FOUNDER');
    expect(wrapper.text()).toContain('€25');
    expect(wrapper.text()).not.toContain('€39');
    expect(wrapper.text()).not.toContain('BILLING_PAGE.CHANGE_PLAN');
    const contact = wrapper
      .findAll('button')
      .find(b => b.text() === 'BILLING_PAGE.CONTACT_TO_CHANGE');
    await contact.trigger('click');
    expect(wrapper.emitted('contact')).toHaveLength(1);
  });

  it('shows Free without an AI meter', () => {
    const wrapper = overview(
      billing({
        has_subscription: false,
        can_buy_plan: true,
        plan: { ...GROWTH, name: 'Free', monthly_price_cents: 0 },
        stripe_details: {},
        products: { ai_conversations: { used: 0, limit: 0, period: 'month' } },
      })
    );

    expect(wrapper.text()).toContain('BILLING_PAGE.NO_AI');
    expect(wrapper.find('[role="progressbar"]').exists()).toBe(false);
    expect(wrapper.text()).toContain('BILLING_PAGE.CHOOSE_PLAN');
  });

  it('shows a pending downgrade with an undo', async () => {
    const wrapper = overview(
      billing({
        pending_plan_change: { plan_name: 'Starter', effective_at: at(18) },
      })
    );

    expect(wrapper.text()).toContain('BILLING_PAGE.PENDING_CHANGE');
    const undo = wrapper
      .findAll('button')
      .find(b => b.text() === 'BILLING_PAGE.UNDO');
    await undo.trigger('click');
    expect(wrapper.emitted('keep')).toHaveLength(1);
  });

  it('shows extra conversations and forecasts the day the allowance runs out', () => {
    const wrapper = overview(billing({ extra_left: 50 }), { canBuy: true });

    expect(wrapper.text()).toContain('BILLING_PAGE.EXTRA {"count":50}');
    expect(wrapper.text()).toContain('BILLING_PAGE.PACE.PROJECTED');
    expect(wrapper.text()).toContain('BILLING_PAGE.BUY_PACK');
  });

  it('says nothing about the pace with too little data', () => {
    const wrapper = overview(
      billing({
        quota_started_at: at(-1),
        products: {
          ai_conversations: { used: 4, limit: 150, period: 'month' },
        },
      })
    );

    expect(wrapper.text()).not.toContain('BILLING_PAGE.PACE');
  });
});

describe('BillingAlert', () => {
  it('shows nothing for a running plan or a trial', () => {
    expect(alertOf(billing()).text()).toBe('');
    expect(alertOf(billing(TRIAL)).text()).toBe('');
  });

  it('gives the day the AI pauses when a payment failed', async () => {
    const wrapper = alertOf(
      billing({ payment_status: 'past_due', ai_pauses_at: at(5) })
    );

    expect(wrapper.text()).toContain('BILLING_PAGE.ALERT.PAST_DUE');
    await wrapper.find('button').trigger('click');
    expect(wrapper.emitted('action')).toEqual([['portal']]);
  });

  it('offers one pack at the limit', async () => {
    const wrapper = alertOf(
      billing({
        ai_replies_paused: true,
        ai_pause_reason: 'limit_reached',
        products: {
          ai_conversations: { used: 150, limit: 150, period: 'month' },
        },
      })
    );

    expect(wrapper.text()).toContain('BILLING_PAGE.ALERT.LIMIT');
    await wrapper.find('button').trigger('click');
    expect(wrapper.emitted('action')).toEqual([['buy']]);
  });

  it('says when the plan ends and offers to resume it', () => {
    const data = billing();
    data.stripe_details.cancel_at_period_end = true;
    const wrapper = alertOf(data);

    expect(wrapper.text()).toContain('BILLING_PAGE.ALERT.CANCELS');
    expect(wrapper.text()).toContain('BILLING_PAGE.RESUME');
  });
});

describe('InvoicesCard', () => {
  it('lists invoices with a pay link for an unpaid one', async () => {
    api.invoices.mockResolvedValue({
      data: {
        invoices: [
          {
            id: 'in_1',
            created: at(-3),
            description: 'Growth, monthly',
            total: 3900,
            currency: 'eur',
            status: 'open',
            pdf_url: 'https://stripe.test/1.pdf',
            pay_url: 'https://stripe.test/1',
          },
        ],
      },
    });
    const wrapper = mount(InvoicesCard);
    await flushPromises();

    expect(wrapper.text()).toContain('Growth, monthly');
    expect(wrapper.text()).toContain('€39.00');
    expect(wrapper.find('a[href="https://stripe.test/1"]').exists()).toBe(true);
  });

  it('stays hidden without invoices', async () => {
    api.invoices.mockResolvedValue({ data: { invoices: [] } });
    const wrapper = mount(InvoicesCard);
    await flushPromises();

    expect(wrapper.find('section').exists()).toBe(false);
  });
});

describe('AutoTopUpCard', () => {
  it('turns auto top-up on with the current cap', async () => {
    api.updateTopUpSettings.mockResolvedValue({});
    const wrapper = mount(AutoTopUpCard, { props: { billing: billing() } });

    expect(wrapper.text()).toContain('BILLING_PAGE.AUTO.OFF');
    await wrapper.find('button[role="switch"], button').trigger('click');
    await flushPromises();

    expect(api.updateTopUpSettings).toHaveBeenCalledWith({
      auto_top_up_enabled: true,
      auto_top_up_max_packs: 2,
    });
    expect(wrapper.emitted('refresh')).toHaveLength(1);
  });
});

describe('PlanPickerDialog', () => {
  const DialogStub = {
    template: '<div><slot /></div>',
    methods: { open() {}, close() {} },
  };
  const picker = data =>
    mount(PlanPickerDialog, {
      props: { billing: data },
      global: { stubs: { Dialog: DialogStub } },
    });
  const actions = wrapper =>
    wrapper.findAll('article').map(card => {
      const button = card.find('button');
      return button.exists() ? button.text() : '';
    });

  it('offers a downgrade, the current plan and an upgrade', () => {
    const wrapper = picker(billing());

    expect(actions(wrapper)).toEqual([
      'BILLING_PAGE.PICKER.DOWNGRADE',
      '',
      'BILLING_PAGE.PICKER.UPGRADE',
    ]);
    expect(wrapper.text()).toContain('BILLING_PAGE.PICKER.CURRENT');
  });

  it('sends every plan to Checkout during the trial', async () => {
    const wrapper = picker(billing(TRIAL));

    expect(
      actions(wrapper).every(label => label === 'BILLING_PAGE.PICKER.CHOOSE')
    ).toBe(true);
    await wrapper.findAll('article')[2].find('button').trigger('click');
    expect(wrapper.emitted('choose')[0][0]).toMatchObject({
      plan: { name: 'Pro' },
      interval: 'month',
    });
  });

  it('warns a founder that another plan loses the founding price', () => {
    expect(picker(billing({ founder_plan: true })).text()).toContain(
      'BILLING_PAGE.PICKER.FOUNDER_NOTE'
    );
  });

  it('shows the annual saving from the prices', () => {
    expect(picker(billing()).text()).toContain(
      'BILLING_PAGE.PICKER.MONTHS_FREE {"count":2}'
    );
  });
});

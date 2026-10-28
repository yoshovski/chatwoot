import { mount } from '@vue/test-utils';
import AddOnList from '../components/AddOnList.vue';
import PlanSummary from '../components/PlanSummary.vue';
import ProductUsageCard from '../components/ProductUsageCard.vue';
import TrialBanner from '../components/TrialBanner.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
    locale: { value: 'en' },
  }),
}));

const DAY = 24 * 60 * 60 * 1000;
const inDays = days => new Date(Date.now() + days * DAY).toISOString();
const billing = (ai, extra = {}) => ({
  trial_enabled: true,
  trial_ends_at: inDays(9.5),
  products: { ai_conversations: ai },
  ...extra,
});

describe('ProductUsageCard', () => {
  const bar = wrapper => wrapper.find('[role="progressbar"] > div');

  it('shows the bar and limit', () => {
    const wrapper = mount(ProductUsageCard, {
      props: {
        icon: 'i-lucide-inbox',
        title: 'Inboxes',
        used: 1,
        limit: 4,
        hint: 'In use',
      },
    });

    expect(wrapper.text()).toContain(
      'ACCOUNT_SUBSCRIPTION.PRODUCTS.OF {"limit":"4"}'
    );
    expect(bar(wrapper).attributes('style')).toContain('width: 25%');
    expect(bar(wrapper).classes()).toContain('bg-n-brand');
    expect(wrapper.text()).toContain('In use');
  });

  it('warns near the limit and turns red at it', () => {
    const near = mount(ProductUsageCard, {
      props: { icon: 'i', title: 'AI', used: 45, limit: 50 },
    });
    const full = mount(ProductUsageCard, {
      props: { icon: 'i', title: 'AI', used: 60, limit: 50 },
    });

    expect(bar(near).classes()).toContain('bg-n-amber-9');
    expect(bar(full).classes()).toContain('bg-n-ruby-9');
    expect(bar(full).attributes('style')).toContain('width: 100%');
  });

  it('says when the plan sets no limit', () => {
    const wrapper = mount(ProductUsageCard, {
      props: { icon: 'i', title: 'Seats', used: 3, limit: null },
    });

    expect(wrapper.find('[role="progressbar"]').exists()).toBe(false);
    expect(wrapper.text()).toContain('ACCOUNT_SUBSCRIPTION.PRODUCTS.NO_LIMIT');
  });
});

describe('TrialBanner', () => {
  it('shows days and AI conversations left in a capped trial', () => {
    const wrapper = mount(TrialBanner, {
      props: { billing: billing({ used: 12, limit: 50, period: 'trial' }) },
    });

    expect(wrapper.text()).toContain('TRIAL_BANNER.DAYS');
    expect(wrapper.text()).toContain(
      'TRIAL_BANNER.AI_LEFT {"left":38,"limit":50}'
    );
    expect(wrapper.classes()).toContain('bg-n-blue-2');
  });

  it('explains the pause when the trial cap is used up', () => {
    const wrapper = mount(TrialBanner, {
      props: { billing: billing({ used: 50, limit: 50, period: 'trial' }) },
    });

    expect(wrapper.text()).toContain('TRIAL_BANNER.CAP_REACHED');
    expect(wrapper.classes()).toContain('bg-n-amber-2');
  });

  it('says the trial ended', () => {
    const wrapper = mount(TrialBanner, {
      props: {
        billing: billing(
          { used: 3, limit: null, period: 'month' },
          { trial_ends_at: inDays(-1) }
        ),
      },
    });

    expect(wrapper.text()).toContain('TRIAL_BANNER.ENDED');
    expect(wrapper.text()).toContain('TRIAL_BANNER.ENDED_HELP');
  });
});

describe('PlanSummary', () => {
  it('shows the plan, price and included features', () => {
    const wrapper = mount(PlanSummary, {
      props: {
        billing: {
          trial_enabled: false,
          payment_status: 'active',
          plan: {
            name: 'Growth',
            description: 'For growing stores',
            currency: 'eur',
            monthly_price_cents: 4900,
            features: ['captain_integration', 'help_center'],
            add_ons: [],
          },
        },
      },
    });

    expect(wrapper.text()).toContain('Growth');
    expect(wrapper.text()).toContain('PLAN.PER_MONTH');
    expect(wrapper.text()).toContain('PLAN.STATUS_ACTIVE');
    expect(wrapper.findAll('li')).toHaveLength(2);
  });

  it('shows an empty state without a plan', () => {
    const wrapper = mount(PlanSummary, { props: { billing: { plan: null } } });

    expect(wrapper.text()).toContain('ACCOUNT_SUBSCRIPTION.PLAN.NONE');
  });
});

describe('AddOnList', () => {
  it('marks bought add-ons as active', () => {
    const wrapper = mount(AddOnList, {
      props: {
        currency: 'eur',
        addOns: [
          { key: 'disable_branding', price_cents: 2000, active: true },
          { key: 'help_center', price_cents: 1000, active: false },
        ],
      },
    });

    const rows = wrapper.findAll('li');
    expect(rows[0].text()).toContain('ADD_ONS.ACTIVE');
    expect(rows[1].text()).toContain('ADD_ONS.AVAILABLE');
  });
});

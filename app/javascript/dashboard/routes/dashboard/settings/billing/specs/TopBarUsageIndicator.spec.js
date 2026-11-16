import { ref } from 'vue';
import { mount } from '@vue/test-utils';
import TopBarUsageIndicator from '../components/TopBarUsageIndicator.vue';

const billingRef = ref(null);
const canManageRef = ref(true);

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
    locale: { value: 'en' },
  }),
}));

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    accountScopedRoute: name => ({ name }),
  }),
}));

vi.mock('dashboard/composables/usePolicy', () => ({
  usePolicy: () => ({
    checkPermissions: () => canManageRef.value,
  }),
}));

vi.mock('dashboard/composables/useAccountSubscription', () => ({
  useAccountSubscription: () => ({
    billing: billingRef,
  }),
}));

const mountIndicator = () =>
  mount(TopBarUsageIndicator, {
    global: {
      directives: {
        onClickOutside: {},
      },
      stubs: {
        RouterLink: {
          props: ['to'],
          template: '<a :href="to.name"><slot /></a>',
        },
      },
    },
  });

describe('TopBarUsageIndicator', () => {
  beforeEach(() => {
    canManageRef.value = true;
    billingRef.value = null;
  });

  it('stays hidden when billing is null or user is not an administrator', () => {
    const emptyWrapper = mountIndicator();
    expect(emptyWrapper.text()).toBe('');

    billingRef.value = {
      enabled: true,
      plan: { name: 'Starter' },
      products: { ai_conversations: { used: 10, limit: 50 } },
    };
    canManageRef.value = false;
    const agentWrapper = mountIndicator();
    expect(agentWrapper.text()).toBe('');
  });

  it('shows usage count, trial badge, popover details, and upgrade CTA', async () => {
    billingRef.value = {
      enabled: true,
      trial_enabled: true,
      trial_ends_at: '2026-12-01T00:00:00Z',
      plan: { name: 'Trial' },
      products: { ai_conversations: { used: 12, limit: 50 } },
      extra_left: 25,
    };

    const wrapper = mountIndicator();
    expect(wrapper.text()).toContain('ACCOUNT_SUBSCRIPTION.TOP_BAR.USAGE_PILL');
    expect(wrapper.text()).toContain('"used":12,"limit":50');
    expect(wrapper.text()).toContain('ACCOUNT_SUBSCRIPTION.TOP_BAR.TRIAL_TAG');
    expect(wrapper.find('a[href="billing_settings_index"]').text()).toBe(
      'BILLING_PAGE.PICKER.UPGRADE'
    );

    await wrapper.find('button').trigger('click');
    expect(wrapper.text()).toContain('Trial');
    expect(wrapper.text()).toContain('BILLING_PAGE.EXTRA {"count":25}');
    expect(wrapper.find('a[href="billing_settings_usage"]').exists()).toBe(
      true
    );
  });

  it('highlights limit reached state in the top-right pill', () => {
    billingRef.value = {
      enabled: true,
      ai_replies_paused: true,
      ai_pause_reason: 'limit_reached',
      plan: { name: 'Starter' },
      products: { ai_conversations: { used: 50, limit: 50 } },
    };

    const wrapper = mountIndicator();
    const button = wrapper.find('button');
    expect(button.text()).toContain(
      'ACCOUNT_SUBSCRIPTION.TOP_BAR.LIMIT_REACHED'
    );
    expect(button.classes()).toContain('text-n-ruby-11');
  });
});

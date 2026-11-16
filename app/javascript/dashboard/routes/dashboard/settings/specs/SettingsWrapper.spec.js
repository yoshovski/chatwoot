import { mount } from '@vue/test-utils';
import { reactive } from 'vue';
import SettingsWrapper from '../SettingsWrapper.vue';

const route = reactive({
  name: 'billing_settings_index',
  params: { accountId: '42' },
  meta: {},
  fullPath: '/app/accounts/42/billing',
});
vi.mock('vue-router', () => ({ useRoute: () => route }));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const global = {
  stubs: {
    RouterView: true,
    RouterLink: {
      name: 'RouterLink',
      props: ['to'],
      template: '<a><slot /></a>',
    },
    Icon: true,
  },
};

describe('Settings back navigation', () => {
  it.each([
    'billing_settings_index',
    'billing_settings_usage',
    'settings_inbox_list',
  ])('returns from %s to Settings in the same account', name => {
    route.name = name;
    const wrapper = mount(SettingsWrapper, { global });
    expect(wrapper.findComponent({ name: 'RouterLink' }).props('to')).toEqual({
      name: 'settings_home',
      params: { accountId: '42' },
    });
  });

  it('returns from channel details to workspace Channels in the same account', () => {
    route.name = 'settings_inbox_show';
    const wrapper = mount(SettingsWrapper, { global });
    expect(wrapper.findComponent({ name: 'RouterLink' }).props('to')).toEqual({
      name: 'settings_inbox_list',
      params: { accountId: '42' },
    });
  });
});

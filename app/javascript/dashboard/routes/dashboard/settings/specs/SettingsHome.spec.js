import { ref } from 'vue';
import { mount } from '@vue/test-utils';
import SettingsHome from '../SettingsHome.vue';
import { SETTINGS_SECTIONS, findSettingsPage } from '../settingsSections';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
  }),
}));

const page = (key, label, keywords) => ({
  key,
  label,
  hint: `${label} hint`,
  keywords,
  route: `${key.toLowerCase()}_route`,
  icon: 'i-lucide-circle',
});

vi.mock('../useSettingsSections', () => ({
  useSettingsSections: () =>
    ref([
      {
        key: 'TEAM',
        title: 'Team',
        hint: 'Who answers',
        icon: 'i-lucide-users',
        pages: [page('TEAMMATES', 'Teammates', 'add a teammate invite')],
      },
      {
        key: 'ACCOUNT',
        title: 'Account',
        hint: 'Your details',
        icon: 'i-lucide-briefcase',
        pages: [page('PROFILE', 'Your profile', 'change my password')],
      },
    ]),
}));

const global = {
  stubs: {
    Icon: true,
    RouterLink: { props: ['to'], template: '<a :href="to.name"><slot /></a>' },
  },
};

describe('SettingsHome', () => {
  it('shows one card per section with its pages', () => {
    const wrapper = mount(SettingsHome, { global });

    expect(wrapper.findAll('h2').map(h => h.text())).toEqual([
      'Team',
      'Account',
    ]);
    expect(wrapper.find('a[href="teammates_route"]').text()).toContain(
      'Teammates'
    );
  });

  it('finds pages by their keywords and says when nothing matches', async () => {
    const wrapper = mount(SettingsHome, { global });
    const input = wrapper.find('input[type="search"]');

    await input.setValue('change password');
    expect(wrapper.findAll('a').map(a => a.attributes('href'))).toEqual([
      'profile_route',
    ]);
    expect(wrapper.text()).toContain('Account');

    await input.setValue('billing');
    expect(wrapper.findAll('a')).toHaveLength(0);
    expect(wrapper.text()).toContain('SETTINGS_HOME.NO_RESULTS');
  });
});

describe('settingsSections', () => {
  it('lists every page once, with its own route in activeOn', () => {
    const pages = SETTINGS_SECTIONS.flatMap(section => section.pages);
    const routes = pages.map(entry => entry.route);

    expect(new Set(routes).size).toBe(routes.length);
    pages.forEach(entry => expect(entry.activeOn).toContain(entry.route));
  });

  it('maps a sub page to the page it belongs to', () => {
    expect(findSettingsPage('settings_teams_edit_members').route).toBe(
      'settings_teams_list'
    );
    expect(findSettingsPage('billing_settings_index')).toBeUndefined();
  });
});

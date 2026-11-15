import { mount, flushPromises } from '@vue/test-utils';
import { reactive } from 'vue';
import SidebarNavigation from '../SidebarNavigation.vue';

const route = reactive({ name: 'home', path: '/home', params: {} });
const push = vi.fn();

vi.mock('vue-router', () => ({
  useRoute: () => route,
  useRouter: () => ({ push, resolve: to => to }),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('../provider', () => ({
  useSidebarContext: () => ({
    isAllowed: () => true,
    resolvePath: to => `/${to.name}`,
  }),
}));

const items = [
  {
    name: 'Home',
    label: 'Home',
    icon: 'i-lucide-house',
    to: { name: 'account_home' },
  },
  {
    name: 'Conversation',
    label: 'Conversations',
    icon: 'i-lucide-messages-square',
    badgeCount: 3,
    children: [
      { name: 'Mine', label: 'My open', to: { name: 'home' } },
      { name: 'Mentions', label: 'Mentions', to: { name: 'mentions' } },
    ],
  },
  {
    name: 'Settings',
    label: 'Settings',
    icon: 'i-lucide-settings',
    to: { name: 'settings_home' },
    children: [
      { name: 'Settings Agents', label: 'Teammates', to: { name: 'agents' } },
    ],
  },
];

const mountNavigation = () =>
  mount(SidebarNavigation, {
    props: { items },
    global: {
      directives: { tooltip: {} },
      stubs: {
        Icon: true,
        AssistantNavigation: true,
        SidebarSubGroup: true,
        SidebarGroupLeaf: {
          props: ['label'],
          template: '<li class="leaf">{{ label }}</li>',
        },
      },
    },
  });

const railButton = (wrapper, label) =>
  wrapper.find(`nav button[aria-label="${label}"]`);

describe('SidebarNavigation', () => {
  beforeEach(() => {
    localStorage.clear();
    push.mockClear();
    Object.assign(route, { name: 'home', path: '/home' });
  });

  it('opens the panel of the current section with its pages', () => {
    const wrapper = mountNavigation();

    expect(wrapper.find('#co-section-panel h2').text()).toBe('Conversations');
    expect(wrapper.findAll('.leaf').map(leaf => leaf.text())).toEqual([
      'My open',
      'Mentions',
    ]);
    expect(
      railButton(wrapper, 'Conversations').attributes('aria-current')
    ).toBe('true');
  });

  it('shows no panel on a section without pages', () => {
    Object.assign(route, { name: 'account_home', path: '/account_home' });
    const wrapper = mountNavigation();

    expect(wrapper.find('#co-section-panel').exists()).toBe(false);
  });

  it('shows the unread count on the rail icon', () => {
    const wrapper = mountNavigation();

    expect(railButton(wrapper, 'Conversations').text()).toBe('3');
  });

  it('hides the panel, remembers it, and moves focus to the rail icon', async () => {
    const wrapper = mountNavigation();

    await wrapper
      .find('button[aria-label="PLATFORM_NAV.HIDE_MENU"]')
      .trigger('click');
    await flushPromises();

    expect(wrapper.find('#co-section-panel').exists()).toBe(false);
    expect(
      railButton(wrapper, 'Conversations').attributes('aria-expanded')
    ).toBe('false');
    expect(JSON.parse(localStorage.getItem('co-nav-collapsed'))).toEqual({
      Conversation: true,
    });
  });

  it('shows a hidden panel again from its rail icon without navigating', async () => {
    localStorage.setItem(
      'co-nav-collapsed',
      JSON.stringify({ Conversation: true })
    );
    const wrapper = mountNavigation();
    expect(wrapper.find('#co-section-panel').exists()).toBe(false);

    await railButton(wrapper, 'Conversations').trigger('click');

    expect(wrapper.find('#co-section-panel').exists()).toBe(true);
    expect(push).not.toHaveBeenCalled();
  });

  it('opens the settings home with no panel, also from a settings page', async () => {
    Object.assign(route, { name: 'agents', path: '/agents' });
    const wrapper = mountNavigation();

    expect(wrapper.find('#co-section-panel').exists()).toBe(false);
    expect(railButton(wrapper, 'Settings').attributes('aria-current')).toBe(
      'true'
    );

    await railButton(wrapper, 'Settings').trigger('click');

    expect(push).toHaveBeenCalledWith({ name: 'settings_home' });
  });

  it('opens another section on its first page', async () => {
    const wrapper = mountNavigation();

    await railButton(wrapper, 'Home').trigger('click');

    expect(push).toHaveBeenCalledWith({ name: 'account_home' });
  });
});

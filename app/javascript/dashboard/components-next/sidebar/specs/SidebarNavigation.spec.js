import { mount, flushPromises } from '@vue/test-utils';
import { reactive } from 'vue';
import SidebarNavigation from '../SidebarNavigation.vue';

const route = reactive({ name: 'home', path: '/home', params: {} });
const push = vi.fn();
const layout = reactive({ isMobile: false, isCompact: false });

vi.mock('../useNavigationLayout', async () => {
  const { toRefs } = await import('vue');
  return { useNavigationLayout: () => toRefs(layout) };
});

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
    Object.assign(layout, { isMobile: false, isCompact: false });
    Object.assign(route, { name: 'home', path: '/home' });
  });

  it('opens the panel of the current section with its pages', () => {
    const wrapper = mountNavigation();

    expect(wrapper.emitted('sectionChange').at(-1)).toEqual([
      { title: 'Conversations', conversation: true },
    ]);
    expect(wrapper.get('#co-section-panel').attributes('aria-label')).toBe(
      'Conversations'
    );
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

  it('hides the panel, remembers it, and keeps a toggle to show it', async () => {
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

    await wrapper
      .find('button[aria-label="PLATFORM_NAV.SHOW_MENU"]')
      .trigger('click');
    expect(wrapper.find('#co-section-panel').exists()).toBe(true);
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

  it('returns to searchable Settings from a settings page without a permanent panel', async () => {
    Object.assign(route, { name: 'agents', path: '/agents' });
    const wrapper = mountNavigation();
    expect(wrapper.find('#co-section-panel').exists()).toBe(false);
    expect(railButton(wrapper, 'Settings').attributes('aria-current')).toBe(
      'true'
    );
    await railButton(wrapper, 'Settings').trigger('click');
    expect(push).toHaveBeenCalledWith({ name: 'settings_home' });
  });

  it('temporarily collapses at tablet widths and restores the desktop choice', async () => {
    const wrapper = mountNavigation();
    layout.isCompact = true;
    await flushPromises();
    expect(wrapper.find('#co-section-panel').exists()).toBe(false);
    await railButton(wrapper, 'Conversations').trigger('click');
    expect(wrapper.find('#co-section-panel').exists()).toBe(true);
    expect(localStorage.getItem('co-nav-collapsed')).toBeNull();
    layout.isCompact = false;
    await flushPromises();
    expect(wrapper.find('#co-section-panel').exists()).toBe(true);
  });

  it('offers the mobile panel without overwriting a collapsed desktop preference', async () => {
    localStorage.setItem(
      'co-nav-collapsed',
      JSON.stringify({ Conversation: true })
    );
    const wrapper = mountNavigation();
    layout.isMobile = true;
    await flushPromises();
    expect(wrapper.find('#co-section-panel').exists()).toBe(true);
    layout.isMobile = false;
    await flushPromises();
    expect(wrapper.find('#co-section-panel').exists()).toBe(false);
    expect(JSON.parse(localStorage.getItem('co-nav-collapsed'))).toEqual({
      Conversation: true,
    });
  });

  it('opens another section on its first page', async () => {
    const wrapper = mountNavigation();

    await railButton(wrapper, 'Home').trigger('click');

    expect(push).toHaveBeenCalledWith({ name: 'account_home' });
  });
});

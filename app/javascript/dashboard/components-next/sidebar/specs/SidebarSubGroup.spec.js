import { mount } from '@vue/test-utils';
import { ref } from 'vue';
import SidebarSubGroup from '../SidebarSubGroup.vue';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { provideSidebarContext } from '../provider';

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ref(1),
}));

vi.mock('dashboard/composables/usePolicy', () => ({
  usePolicy: () => ({
    shouldShow: () => true,
  }),
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({
    resolve: () => ({ path: '/' }),
    getRoutes: () => [],
  }),
}));

const children = [
  {
    name: 'Sales-1',
    label: 'Sales',
    to: { name: 'team_conversations' },
  },
];

const mountSubGroup = props => {
  return mount(
    {
      components: { SidebarSubGroup },
      setup() {
        provideSidebarContext({});
      },
      template: '<SidebarSubGroup v-bind="$attrs" />',
    },
    {
      attrs: {
        name: 'Conversation:Teams',
        label: 'Teams',
        icon: 'i-lucide-users',
        children,
        isExpanded: true,
        collapsible: true,
        ...props,
      },
      global: {
        stubs: {
          SidebarGroupLeaf: {
            props: { label: { type: String, required: true } },
            template: '<li class="sidebar-leaf">{{ label }}</li>',
          },
          Icon: {
            props: ['icon'],
            template: '<span class="icon-stub" :data-icon="icon" />',
          },
        },
      },
    }
  );
};

describe('SidebarSubGroup', () => {
  let localStorageStore;

  beforeEach(() => {
    localStorageStore = {};
    Object.defineProperty(window, 'localStorage', {
      value: {
        getItem: key => localStorageStore[key] || null,
        setItem: (key, value) => {
          localStorageStore[key] = String(value);
        },
        removeItem: key => {
          delete localStorageStore[key];
        },
        clear: () => {
          localStorageStore = {};
        },
      },
      configurable: true,
    });

    window.localStorage.clear();
  });

  it('keeps collapsible sections expanded by default', () => {
    const wrapper = mountSubGroup();

    expect(wrapper.find('button').attributes('aria-expanded')).toBe('true');
    expect(wrapper.find('.sidebar-leaf').isVisible()).toBe(true);
  });

  it('shows the group label in the header', () => {
    const wrapper = mountSubGroup();

    expect(wrapper.find('button').text()).toBe('Teams');
  });

  it('shows an up caret next to the label while expanded', () => {
    const wrapper = mountSubGroup();

    expect(wrapper.find('button .icon-stub').attributes('data-icon')).toBe(
      'i-lucide-chevron-up'
    );
  });

  it('shows a down caret once the group is minimized', async () => {
    const wrapper = mountSubGroup();

    await wrapper.find('button').trigger('click');

    expect(wrapper.find('button .icon-stub').attributes('data-icon')).toBe(
      'i-lucide-chevron-down'
    );
  });

  it('draws no tree connectors around the header', () => {
    const wrapper = mountSubGroup();

    expect(wrapper.html()).not.toContain('before:bg-n-slate-4');
  });

  it('minimizes the section and stores it by account and section name', async () => {
    const wrapper = mountSubGroup();

    await wrapper.find('button').trigger('click');

    const storedSections = JSON.parse(
      window.localStorage.getItem(LOCAL_STORAGE_KEYS.SIDEBAR_MINIMIZED_SECTIONS)
    );
    expect(wrapper.find('button').attributes('aria-expanded')).toBe('false');
    expect(wrapper.find('.sidebar-leaf').isVisible()).toBe(false);
    expect(storedSections).toEqual({ '1:Conversation:Teams': true });
  });

  it('uses the stored minimized state when mounted again', () => {
    window.localStorage.setItem(
      LOCAL_STORAGE_KEYS.SIDEBAR_MINIMIZED_SECTIONS,
      JSON.stringify({ '1:Conversation:Teams': true })
    );

    const wrapper = mountSubGroup();

    expect(wrapper.find('button').attributes('aria-expanded')).toBe('false');
    expect(wrapper.find('.sidebar-leaf').isVisible()).toBe(false);
  });

  it('expands a stored minimized section when one of its children is active', () => {
    window.localStorage.setItem(
      LOCAL_STORAGE_KEYS.SIDEBAR_MINIMIZED_SECTIONS,
      JSON.stringify({ '1:Conversation:Teams': true })
    );

    const wrapper = mountSubGroup({ activeChild: children[0] });

    const storedSections = JSON.parse(
      window.localStorage.getItem(LOCAL_STORAGE_KEYS.SIDEBAR_MINIMIZED_SECTIONS)
    );
    expect(wrapper.find('button').attributes('aria-expanded')).toBe('true');
    expect(wrapper.find('.sidebar-leaf').isVisible()).toBe(true);
    expect(storedSections).toEqual({});
  });
});

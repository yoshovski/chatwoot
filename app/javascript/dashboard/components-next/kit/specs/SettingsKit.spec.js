import { flushPromises, mount } from '@vue/test-utils';
import { createMemoryHistory, createRouter } from 'vue-router';
import { withFullI18n } from 'test-i18n';
import DataTable from '../DataTable.vue';
import FormLayout from '../FormLayout.vue';
import SearchField from '../SearchField.vue';
import TableCard from '../TableCard.vue';

withFullI18n();

const global = {
  stubs: {
    Icon: { props: ['icon'], template: '<i :data-icon="icon" />' },
    RouterLink: { template: '<a><slot /></a>' },
    Button: {
      props: ['label', 'disabled', 'isLoading', 'type'],
      template:
        '<button :type="type" :disabled="disabled">{{ label }}</button>',
    },
  },
};

const columns = [
  { key: 'name', label: 'Name' },
  { key: 'actions', label: 'Actions', end: true, hideLabel: true },
];
const rows = [
  { id: 1, name: 'Maya', email: 'maya@example.com' },
  { id: 2, name: 'Tom', email: 'tom@example.com' },
];
const tableProps = {
  columns,
  rows,
  loadingText: 'Loading',
  errorText: 'Could not load',
  retryLabel: 'Try again',
  emptyTitle: 'Nobody yet',
  noResultsText: 'No match',
};

describe('SearchField', () => {
  it('binds the query and labels the input with the placeholder', async () => {
    const wrapper = mount(SearchField, {
      global,
      props: { placeholder: 'Search teams', modelValue: '' },
    });

    await wrapper.find('input').setValue('sales');

    expect(wrapper.find('input').attributes('aria-label')).toBe('Search teams');
    expect(wrapper.emitted('update:modelValue')[0]).toEqual(['sales']);
  });
});

describe('DataTable', () => {
  it('prints plain cells, uses cell slots and hides labels on request', () => {
    const wrapper = mount(DataTable, {
      global,
      props: { columns, rows },
      slots: { 'cell-actions': '<button>Edit</button>' },
    });

    expect(wrapper.findAll('tbody tr')).toHaveLength(2);
    expect(wrapper.find('tbody tr').text()).toContain('Maya');
    expect(wrapper.find('tbody tr').text()).toContain('Edit');
    expect(wrapper.findAll('th')[1].find('.sr-only').text()).toBe('Actions');
    expect(wrapper.findAll('th')[1].classes()).toContain('text-end');
  });
});

describe('TableCard', () => {
  it('shows loading, then error with retry, then empty with the action', async () => {
    const loading = mount(TableCard, {
      global,
      props: { ...tableProps, loading: true },
    });
    expect(loading.find('[role="status"]').text()).toBe('Loading');

    const failed = mount(TableCard, {
      global,
      props: { ...tableProps, error: true },
    });
    expect(failed.text()).toContain('Could not load');
    await failed.find('button').trigger('click');
    expect(failed.emitted('retry')).toHaveLength(1);

    const empty = mount(TableCard, {
      global,
      props: { ...tableProps, rows: [] },
      slots: { empty: '<button>Invite</button>' },
    });
    expect(empty.text()).toContain('Nobody yet');
    expect(empty.text()).toContain('Invite');
    expect(empty.find('table').exists()).toBe(false);

    await empty.setProps({ unavailableText: 'Your role cannot view this' });
    expect(empty.text()).toContain('Your role cannot view this');
    expect(empty.text()).not.toContain('Nobody yet');
    expect(empty.find('button').exists()).toBe(false);
  });

  it('filters rows by the search keys and says when nothing matches', async () => {
    const wrapper = mount(TableCard, {
      global,
      props: {
        ...tableProps,
        searchKeys: ['name', 'email'],
        searchPlaceholder: 'Search',
        count: '2 teammates',
      },
    });

    expect(wrapper.text()).toContain('2 teammates');
    await wrapper.find('input[type="search"]').setValue('tom');
    expect(wrapper.findAll('tbody tr')).toHaveLength(1);
    expect(wrapper.find('tbody tr').text()).toContain('Tom');

    await wrapper.find('input[type="search"]').setValue('zzz');
    expect(wrapper.find('table').exists()).toBe(false);
    expect(wrapper.text()).toContain('No match');
    await wrapper.get('button').trigger('click');
    expect(wrapper.get('input').element.value).toBe('');
    expect(wrapper.findAll('tbody tr')).toHaveLength(2);
  });
});

describe('FormLayout', () => {
  it('saves on submit and shows "Saved" only after a save', async () => {
    const wrapper = mount(FormLayout, {
      global,
      props: { saveLabel: 'Save', savedLabel: 'Saved' },
      slots: { default: '<section>Card</section>', status: '2 selected' },
    });

    expect(wrapper.text()).not.toContain('Saved');
    expect(wrapper.text()).toContain('2 selected');
    await wrapper.find('form').trigger('submit');
    expect(wrapper.emitted('save')).toHaveLength(1);

    await wrapper.setProps({ saved: true });
    expect(wrapper.find('[role="status"]').text()).toContain('Saved');
  });

  it('turns the button off while saving or when disabled', async () => {
    const wrapper = mount(FormLayout, {
      global,
      props: { saveLabel: 'Save', saving: true },
    });

    expect(wrapper.find('button').attributes('disabled')).toBeDefined();
    await wrapper.get('form').trigger('submit');
    await wrapper.setProps({ saving: false, disabled: true });
    expect(wrapper.find('button').attributes('disabled')).toBeDefined();
    await wrapper.get('form').trigger('submit');
    expect(wrapper.emitted('save')).toBeUndefined();
    await wrapper.setProps({ disabled: false });
    expect(wrapper.find('button').attributes('disabled')).toBeUndefined();
  });
});

describe('explicit-save forms', () => {
  const dialog = {
    emits: ['confirm', 'close'],
    methods: { open: vi.fn(), close: vi.fn() },
    template: '<div />',
  };
  const stubs = { ...global.stubs, Dialog: dialog };

  it('guards dirty navigation until the user confirms leaving', async () => {
    const router = createRouter({
      history: createMemoryHistory(),
      routes: [
        {
          path: '/',
          component: FormLayout,
          props: { saveLabel: 'Save', dirty: true },
        },
        { path: '/next', component: { template: '<p>Next</p>' } },
      ],
    });
    await router.push('/');
    const wrapper = mount(
      { template: '<router-view />' },
      {
        global: { plugins: [router], stubs },
      }
    );

    const canceled = router.push('/next');
    await flushPromises();
    expect(dialog.methods.open).toHaveBeenCalledTimes(1);
    wrapper.getComponent(dialog).vm.$emit('close');
    await canceled;
    expect(router.currentRoute.value.path).toBe('/');

    const confirmed = router.push('/next');
    await flushPromises();
    wrapper.getComponent(dialog).vm.$emit('confirm');
    await confirmed;
    expect(router.currentRoute.value.path).toBe('/next');
    wrapper.unmount();
  });

  it('preserves input on failure and warns about leaving while dirty', async () => {
    const wrapper = mount(FormLayout, {
      global: { stubs },
      attachTo: document.body,
      props: { saveLabel: 'Save', dirty: false },
      slots: { default: '<input aria-invalid="true" />' },
    });
    const input = wrapper.get('input');
    await wrapper.get('form').trigger('submit');
    expect(wrapper.emitted('save')).toBeUndefined();

    await input.setValue('Draft');
    await wrapper.setProps({ dirty: true });
    await wrapper.get('form').trigger('submit');
    expect(wrapper.emitted('save')).toHaveLength(1);
    await wrapper.setProps({ error: 'Review your name' });
    expect(wrapper.get('[role="alert"]').text()).toBe('Review your name');
    expect(input.element.value).toBe('Draft');
    expect(document.activeElement).toBe(input.element);

    const beforeUnload = new Event('beforeunload', { cancelable: true });
    window.dispatchEvent(beforeUnload);
    expect(beforeUnload.defaultPrevented).toBe(true);
    await wrapper.get('button[type="button"]').trigger('click');
    expect(wrapper.emitted('discard')).toHaveLength(1);
    wrapper.unmount();
  });
});

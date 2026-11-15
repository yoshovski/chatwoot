import { mount } from '@vue/test-utils';
import DataTable from '../DataTable.vue';
import FormLayout from '../FormLayout.vue';
import SearchField from '../SearchField.vue';
import TableCard from '../TableCard.vue';

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
    await wrapper.setProps({ saving: false, disabled: true });
    expect(wrapper.find('button').attributes('disabled')).toBeDefined();
    await wrapper.setProps({ disabled: false });
    expect(wrapper.find('button').attributes('disabled')).toBeUndefined();
  });
});

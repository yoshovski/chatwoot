import { shallowMount } from '@vue/test-utils';
import CustomerTable from './CustomerTable.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params?.name ? `Select ${params.name}` : key),
  }),
}));

const contacts = [
  {
    id: 1,
    name: 'Alex',
    email: 'alex@example.com',
    labels: ['returning'],
    conversations_count: 2,
    availability_status: 'online',
    website_activity: {
      current_page: { title: 'Help', url: 'https://example.com/help' },
      arrival: { utm_source: 'newsletter' },
    },
  },
  {
    id: 2,
    name: 'Bea',
    email: 'bea@example.com',
    labels: [],
    conversations_count: 0,
    availability_status: 'offline',
    website_activity: { current_page: { title: 'Old page' } },
  },
];

describe('CustomerTable', () => {
  it('selects a row independently of opening the profile', async () => {
    const wrapper = shallowMount(CustomerTable, {
      props: { contacts, columns: ['email'] },
    });
    await wrapper.get('input[aria-label="Select Alex"]').setValue(true);
    expect(wrapper.emitted('select')).toEqual([[1, true]]);
    expect(wrapper.emitted('open')).toBeUndefined();
    await wrapper.findAll('tbody button')[0].trigger('click');
    expect(wrapper.emitted('open')[0][0].id).toBe(1);
  });

  it('marks partial page selection and can select all visible rows', async () => {
    const wrapper = shallowMount(CustomerTable, {
      props: { contacts, selectedIds: [1] },
    });
    const checkbox = wrapper.get('thead input');
    expect(checkbox.element.indeterminate).toBe(true);
    await checkbox.setValue(true);
    expect(wrapper.emitted('selectAll')).toEqual([[true]]);
  });

  it('disables selection while an action is being queued', () => {
    const wrapper = shallowMount(CustomerTable, {
      props: { contacts, disabled: true },
    });
    expect(
      wrapper.findAll('input').every(input => input.element.disabled)
    ).toBe(true);
  });

  it('shows current pages only for online customers and uses the recorded arrival source', () => {
    const wrapper = shallowMount(CustomerTable, {
      props: { contacts, columns: ['source'], online: true },
    });
    expect(wrapper.text()).toContain('Help');
    expect(wrapper.text()).not.toContain('Old page');
    expect(wrapper.text()).toContain('newsletter');
  });

  it('requests server sorting for conversation count', async () => {
    const wrapper = shallowMount(CustomerTable, {
      props: { contacts, columns: ['conversations_count'] },
    });
    await wrapper.findAll('thead button')[1].trigger('click');
    expect(wrapper.emitted('sort')).toEqual([['conversations_count']]);
  });
});

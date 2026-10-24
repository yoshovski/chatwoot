import { mount } from '@vue/test-utils';
import HubspotSettingsForm from './HubspotSettingsForm.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const properties = [
  { name: 'email', label: 'Email' },
  { name: 'firstname', label: 'First Name' },
  { name: 'lastname', label: 'Last Name' },
  { name: 'phone', label: 'Phone Number' },
  { name: 'chatoctave_lead_type', label: 'Lead type' },
  { name: 'company', label: 'Company name' },
  { name: 'jobtitle', label: 'Job title' },
];

const sources = [
  { key: 'email', label: 'Email' },
  { key: 'firstname', label: 'First name' },
  { key: 'lastname', label: 'Last name' },
  { key: 'phone', label: 'Phone' },
  { key: 'lead_type', label: 'Lead type' },
  { key: 'lead_summary', label: 'Lead summary' },
  { key: 'lead_source', label: 'Lead source' },
  { key: 'lead_company', label: 'Company', kind: 'lead' },
  { key: 'lead_country', label: 'Country', kind: 'lead' },
  { key: 'lead_audience_size', label: 'Audience size', kind: 'lead' },
  { key: 'lead_use_case', label: 'Use case', kind: 'lead' },
  { key: 'job_title', label: 'Job title', kind: 'attribute' },
];

const settings = {
  sync_contacts: true,
  save_transcripts: false,
  field_mapping: {
    email: 'email',
    firstname: 'firstname',
    lastname: 'lastname',
    phone: 'phone',
  },
};

const mountForm = (props = {}) =>
  mount(HubspotSettingsForm, {
    props: { settings, properties, sources, ...props },
  });

const rowComboBox = (wrapper, key) =>
  wrapper.find(`[data-test="mapping-row-${key}"]`).findComponent(ComboBox);

describe('HubspotSettingsForm', () => {
  it('shows the fixed rows, keeps email read-only and suggests existing lead properties', () => {
    const wrapper = mountForm();

    [
      'email',
      'firstname',
      'lastname',
      'phone',
      'lead_type',
      'lead_summary',
      'lead_source',
      'lead_company',
      'lead_country',
      'lead_audience_size',
      'lead_use_case',
    ].forEach(key => {
      expect(wrapper.find(`[data-test="mapping-row-${key}"]`).exists()).toBe(
        true
      );
    });
    expect(rowComboBox(wrapper, 'email').props('disabled')).toBe(true);
    expect(rowComboBox(wrapper, 'lead_type').props('modelValue')).toBe(
      'chatoctave_lead_type'
    );
    expect(rowComboBox(wrapper, 'lead_summary').props('modelValue')).toBe('');
  });

  it('emits only mapped rows with the toggles', async () => {
    const wrapper = mountForm();

    await wrapper.findAllComponents(Switch)[0].trigger('click');
    await wrapper.find('form').trigger('submit');

    expect(wrapper.emitted('save')[0][0]).toEqual({
      field_mapping: {
        email: 'email',
        firstname: 'firstname',
        lastname: 'lastname',
        phone: 'phone',
        lead_type: 'chatoctave_lead_type',
      },
      sync_contacts: false,
      save_transcripts: false,
    });
  });

  it('keeps additional contact fields available in the picker', async () => {
    const wrapper = mountForm();

    wrapper
      .find('[data-test="add-mapping"]')
      .findComponent(ComboBox)
      .vm.$emit('update:modelValue', 'job_title');
    await wrapper.vm.$nextTick();
    rowComboBox(wrapper, 'job_title').vm.$emit('update:modelValue', 'jobtitle');
    await wrapper.find('form').trigger('submit');

    expect(wrapper.emitted('save')[0][0].field_mapping.job_title).toBe(
      'jobtitle'
    );
  });

  it('flags a HubSpot property mapped twice and blocks saving', async () => {
    const wrapper = mountForm();

    rowComboBox(wrapper, 'lastname').vm.$emit('update:modelValue', 'firstname');
    await wrapper.vm.$nextTick();

    expect(rowComboBox(wrapper, 'lastname').props('hasError')).toBe(true);
    expect(rowComboBox(wrapper, 'firstname').props('hasError')).toBe(true);
    expect(
      wrapper.find('button[type="submit"]').attributes('disabled')
    ).toBeDefined();
  });
});

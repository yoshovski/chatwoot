import { mount } from '@vue/test-utils';
import TemplateField from './TemplateField.vue';
import StepCard from './StepCard.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const variables = { inputs: ['email'], outputs: [], contact: [] };
const stubs = { VariablePicker: true, ComboBox: true, StepAuth: true };

const mountField = modelValue =>
  mount(TemplateField, {
    props: { modelValue, variables },
    global: { stubs },
  });

describe('TemplateField', () => {
  it('shows variables as tags and keeps the rest as text', () => {
    const wrapper = mountField('{"email": "{{ email }}"}');
    const tags = wrapper.findAll('[data-raw]');

    expect(tags).toHaveLength(1);
    expect(tags[0].text()).toBe('email');
    expect(wrapper.find('[data-test="template-field"]').text()).toContain(
      '{"email": "'
    );
  });

  it('removes a variable with its x and emits the template without it', async () => {
    const wrapper = mountField('Hi {{ outputs.name }}!');

    await wrapper.find('[data-remove]').trigger('click');

    expect(wrapper.emitted('update:modelValue').at(-1)).toEqual(['Hi !']);
  });

  it('inserts a picked variable as a tag', async () => {
    const wrapper = mountField('Order ');

    await wrapper
      .findComponent({ name: 'VariablePicker' })
      .vm.$emit('insert', '{{ email }}');

    expect(wrapper.emitted('update:modelValue').at(-1)).toEqual([
      'Order {{ email }}',
    ]);
    expect(wrapper.findAll('[data-raw]')).toHaveLength(1);
  });
});

describe('StepCard check', () => {
  const mountCheck = compare =>
    mount(StepCard, {
      props: {
        variables,
        step: { key: 'check', type: 'verify', left: '', right: '', compare },
      },
      global: { stubs },
    });

  it('asks for a value to compare with, except for "is not empty"', () => {
    expect(mountCheck('exact').findAllComponents(TemplateField)).toHaveLength(
      2
    );
    expect(mountCheck('present').findAllComponents(TemplateField)).toHaveLength(
      1
    );
  });
});

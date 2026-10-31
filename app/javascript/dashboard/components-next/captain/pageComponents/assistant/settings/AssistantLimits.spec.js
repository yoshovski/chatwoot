import { mount } from '@vue/test-utils';
import AssistantLimits from './AssistantLimits.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const stubs = {
  SettingsCard: { template: '<section><slot /></section>' },
  Input: {
    props: ['modelValue'],
    emits: ['update:modelValue'],
    template:
      '<input :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" />',
  },
  Select: {
    props: ['modelValue', 'options'],
    emits: ['update:modelValue'],
    template:
      '<select :value="modelValue" @change="$emit(\'update:modelValue\', $event.target.value)"><option v-for="option in options" :key="option.value" :value="option.value">{{ option.label }}</option></select>',
  },
  Button: {
    props: ['label', 'ariaLabel', 'disabled'],
    emits: ['click'],
    template:
      '<button :aria-label="ariaLabel" :disabled="disabled" @click="$emit(\'click\')">{{ label }}</button>',
  },
};

const assistant = {
  name: 'Ava',
  config: {
    product_name: 'Acme',
    limits: [{ cannot: 'issue refunds', offer: 'handoff' }],
  },
};

const mountLimits = (props = { assistant }) =>
  mount(AssistantLimits, { props, global: { stubs } });

const buttonWithLabel = (wrapper, label) =>
  wrapper.findAll('button').find(button => button.text() === label);

const prefix = 'CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIMITS';

describe('AssistantLimits', () => {
  it('adds a limit and saves it with the rest of the config', async () => {
    const wrapper = mountLimits();
    expect(wrapper.findAll('[data-test-id="limit-row"]')).toHaveLength(1);

    await buttonWithLabel(wrapper, `${prefix}.ADD`).trigger('click');
    const row = wrapper.findAll('[data-test-id="limit-row"]')[1];
    await row.find('input').setValue('  give legal advice ');
    await row.find('select').setValue('link');
    await row.findAll('input')[1].setValue('https://example.com/legal');
    await buttonWithLabel(wrapper, 'CAPTAIN.ASSISTANTS.SETTINGS.SAVE').trigger(
      'click'
    );

    expect(wrapper.emitted('submit')[0][0]).toEqual({
      config: {
        product_name: 'Acme',
        limits: [
          { cannot: 'issue refunds', offer: 'handoff' },
          {
            cannot: 'give legal advice',
            offer: 'link',
            value: 'https://example.com/legal',
          },
        ],
      },
    });
  });

  it('removes a limit', async () => {
    const wrapper = mountLimits();

    await wrapper.find(`[aria-label="${prefix}.REMOVE"]`).trigger('click');
    await buttonWithLabel(wrapper, 'CAPTAIN.ASSISTANTS.SETTINGS.SAVE').trigger(
      'click'
    );

    expect(wrapper.emitted('submit')[0][0].config.limits).toEqual([]);
  });

  it('does not save a link without a valid URL or a blank limit', async () => {
    const wrapper = mountLimits();

    await buttonWithLabel(wrapper, `${prefix}.ADD`).trigger('click');
    const row = wrapper.findAll('[data-test-id="limit-row"]')[1];
    await row.find('select').setValue('link');
    await row.findAll('input')[1].setValue('example.com');
    await buttonWithLabel(wrapper, 'CAPTAIN.ASSISTANTS.SETTINGS.SAVE').trigger(
      'click'
    );

    expect(wrapper.emitted('submit')).toBeUndefined();
    expect(wrapper.text()).toContain(`${prefix}.ERRORS.CANNOT_REQUIRED`);

    await row.find('input').setValue('give legal advice');
    await buttonWithLabel(wrapper, 'CAPTAIN.ASSISTANTS.SETTINGS.SAVE').trigger(
      'click'
    );

    expect(wrapper.emitted('submit')).toBeUndefined();
    expect(wrapper.text()).toContain(`${prefix}.ERRORS.LINK`);
  });

  it('stops adding after 15 limits', () => {
    const limits = Array.from({ length: 15 }, (_, index) => ({
      cannot: `do thing ${index}`,
      offer: 'handoff',
    }));
    const wrapper = mountLimits({
      assistant: { name: 'Ava', config: { limits } },
    });

    expect(
      buttonWithLabel(wrapper, `${prefix}.ADD`).attributes('disabled')
    ).toBeDefined();
  });
});

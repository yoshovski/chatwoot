import { shallowMount } from '@vue/test-utils';
import Button from 'dashboard/components-next/button/Button.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import AssistantOffLimitsMessage from './AssistantOffLimitsMessage.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const assistant = {
  name: 'Luna',
  config: { product_name: 'Acme', off_limits_message: 'Old wording' },
};

describe('AssistantOffLimitsMessage', () => {
  it('saves the trimmed message and keeps the rest of the config', async () => {
    const wrapper = shallowMount(AssistantOffLimitsMessage, {
      props: { assistant },
      global: { stubs: { SettingsCard: false } },
    });

    expect(wrapper.findComponent(TextArea).props('modelValue')).toBe(
      'Old wording'
    );
    wrapper
      .findComponent(TextArea)
      .vm.$emit('update:modelValue', '  I only help with Acme orders.  ');
    await wrapper.vm.$nextTick();
    wrapper.findComponent(Button).vm.$emit('click');

    expect(wrapper.emitted('submit')[0][0]).toEqual({
      config: {
        product_name: 'Acme',
        off_limits_message: 'I only help with Acme orders.',
      },
    });
  });
});

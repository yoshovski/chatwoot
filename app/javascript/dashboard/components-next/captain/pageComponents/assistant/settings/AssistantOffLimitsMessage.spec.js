import { shallowMount } from '@vue/test-utils';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import AssistantOffLimitsMessage from './AssistantOffLimitsMessage.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

describe('AssistantOffLimitsMessage', () => {
  it('updates the shared rules draft', async () => {
    const wrapper = shallowMount(AssistantOffLimitsMessage, {
      props: { modelValue: 'Old wording' },
    });

    expect(wrapper.findComponent(TextArea).props('modelValue')).toBe(
      'Old wording'
    );
    wrapper
      .findComponent(TextArea)
      .vm.$emit('update:modelValue', '  I only help with Acme orders.  ');
    await wrapper.vm.$nextTick();
    expect(wrapper.emitted('update:modelValue')[0]).toEqual([
      '  I only help with Acme orders.  ',
    ]);
  });
});

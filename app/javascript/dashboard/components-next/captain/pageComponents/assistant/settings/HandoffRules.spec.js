import { shallowMount } from '@vue/test-utils';
import HandoffRules from './HandoffRules.vue';
import AddNewRulesInput from 'dashboard/components-next/captain/assistant/AddNewRulesInput.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const LEGAL = 'CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.RULES.PRESETS.LEGAL.TEXT';

const mountRules = modelValue =>
  shallowMount(HandoffRules, {
    props: {
      modelValue,
      'onUpdate:modelValue': value => value,
    },
    global: { directives: { tooltip: {} } },
  });

describe('HandoffRules', () => {
  it('adds a preset once and stops offering it', async () => {
    const wrapper = mountRules([]);
    const presets = wrapper.findAll('button[type="button"]');

    expect(presets).toHaveLength(5);
    await presets[0].trigger('click');
    expect(wrapper.emitted('update:modelValue')[0][0]).toEqual([LEGAL]);

    await wrapper.setProps({ modelValue: [LEGAL] });
    expect(wrapper.findAll('button[type="button"]')).toHaveLength(4);
  });

  it('adds a written rule and hides adding at the limit', async () => {
    const wrapper = mountRules([]);

    wrapper.findComponent(AddNewRulesInput).vm.$emit('add', 'Hand off VIPs.');
    expect(wrapper.emitted('update:modelValue')[0][0]).toEqual([
      'Hand off VIPs.',
    ]);

    await wrapper.setProps({
      modelValue: Array.from({ length: 10 }, (_, i) => `Rule ${i}`),
    });
    expect(wrapper.findComponent(AddNewRulesInput).exists()).toBe(false);
  });
});

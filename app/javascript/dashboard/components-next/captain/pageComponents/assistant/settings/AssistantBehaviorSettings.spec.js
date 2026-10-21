import { shallowMount } from '@vue/test-utils';
import Button from 'dashboard/components-next/button/Button.vue';
import AssistantBehaviorSettings from './AssistantBehaviorSettings.vue';
import ChoiceCard from './ChoiceCard.vue';
import SettingsSwitchRow from './SettingsSwitchRow.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const mountSettings = (config, showProductCards = true) =>
  shallowMount(AssistantBehaviorSettings, {
    props: { assistant: { name: 'Luna', config }, showProductCards },
    global: { stubs: { SettingsCard: false } },
  });

describe('AssistantBehaviorSettings', () => {
  it('hides commerce settings when Shopify is unavailable', () => {
    const wrapper = mountSettings({}, false);
    expect(wrapper.findAllComponents(SettingsSwitchRow)).toHaveLength(2);
  });

  it('marks the saved tone and emits a new one', () => {
    const wrapper = mountSettings({ tone: 'professional' });
    const tones = wrapper.findAllComponents(ChoiceCard);

    expect(tones.map(tone => tone.props('isActive'))).toEqual([
      false,
      true,
      false,
    ]);
    tones[2].vm.$emit('select', 'short');
    expect(wrapper.emitted('update')[0][0]).toEqual({ tone: 'short' });
  });

  it('emits each reply format switch as its own config key', () => {
    const wrapper = mountSettings({ suggested_replies: true });
    const rows = wrapper.findAllComponents(SettingsSwitchRow);

    expect(rows[0].props('modelValue')).toBe(true);
    rows[1].vm.$emit('update:modelValue', true);
    rows[2].vm.$emit('update:modelValue', true);

    expect(wrapper.emitted('update')).toEqual([
      [{ feature_citation: true }],
      [{ product_cards: true }],
    ]);
  });

  it('shows the button count only while quick replies are on', () => {
    expect(mountSettings({}).findAllComponents(Button)).toHaveLength(0);

    const wrapper = mountSettings({
      suggested_replies: true,
      max_suggested_replies: 2,
    });
    const [fewer, more] = wrapper.findAllComponents(Button);
    more.vm.$emit('click');
    fewer.vm.$emit('click');

    expect(wrapper.emitted('update')).toEqual([
      [{ max_suggested_replies: 3 }],
      [{ max_suggested_replies: 1 }],
    ]);
  });
});

import { shallowMount } from '@vue/test-utils';
import Button from 'dashboard/components-next/button/Button.vue';
import AssistantBehaviorSettings from './AssistantBehaviorSettings.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import ChoiceCard from './ChoiceCard.vue';
import SettingsSwitchRow from './SettingsSwitchRow.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key}:${params.type}` : key),
  }),
}));

const mountSettings = (config, showProductCards = true, assistant = {}) =>
  shallowMount(AssistantBehaviorSettings, {
    props: {
      assistant: { name: 'Luna', config, ...assistant },
      showProductCards,
    },
    global: { stubs: { SettingsCard: false } },
  });

describe('AssistantBehaviorSettings', () => {
  it('hides commerce settings when Shopify is unavailable', () => {
    const wrapper = mountSettings({}, false);
    expect(wrapper.findAllComponents(SettingsSwitchRow)).toHaveLength(2);
  });

  it('offers the detected business type as the automatic choice', () => {
    const wrapper = mountSettings({}, false, {
      detected_business_type: 'software',
    });
    const select = wrapper.findComponent(Select);

    expect(select.props('modelValue')).toBe('');
    expect(select.props('options')[0].label).toBe(
      'CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.BUSINESS_TYPE.AUTO:CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.BUSINESS_TYPE.OPTIONS.SOFTWARE'
    );
    select.vm.$emit('update:modelValue', 'subscription');
    expect(wrapper.emitted('update')[0][0]).toEqual({
      business_type: 'subscription',
    });
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

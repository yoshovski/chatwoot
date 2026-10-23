import { shallowMount } from '@vue/test-utils';
import Button from 'dashboard/components-next/button/Button.vue';
import AssistantBehaviorSettings from './AssistantBehaviorSettings.vue';
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

  it('selects the detected business type until one is chosen', () => {
    const wrapper = mountSettings({}, false, {
      detected_business_type: 'software',
    });
    const chips = wrapper.findAll('[role="radio"]');
    const checked = chips.filter(
      chip => chip.attributes('aria-checked') === 'true'
    );

    expect(checked).toHaveLength(1);
    expect(checked[0].text()).toContain('OPTIONS.SOFTWARE');
    expect(checked[0].text()).toContain('BUSINESS_TYPE.DETECTED');
    chips[2].trigger('click');
    expect(wrapper.emitted('update')[0][0]).toEqual({
      business_type: 'subscription',
    });
  });

  it('resets a chosen business type to detection', () => {
    const wrapper = mountSettings({ business_type: 'services' });
    const reset = wrapper
      .findAllComponents(Button)
      .find(button => button.props('label').includes('USE_DETECTED'));

    reset.vm.$emit('click');
    expect(wrapper.emitted('update')[0][0]).toEqual({ business_type: '' });
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

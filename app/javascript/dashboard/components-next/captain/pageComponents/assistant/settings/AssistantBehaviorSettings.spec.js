import { shallowMount } from '@vue/test-utils';
import Button from 'dashboard/components-next/button/Button.vue';
import AssistantBehaviorSettings from './AssistantBehaviorSettings.vue';
import PresetPromptEditor from './PresetPromptEditor.vue';
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
    // Quick replies, sources and follow-up questions; no product cards.
    expect(wrapper.findAllComponents(SettingsSwitchRow)).toHaveLength(3);
  });

  it('turns follow-up questions off for non-shops only', () => {
    const wrapper = mountSettings({}, false);
    const followUp = wrapper.findAllComponents(SettingsSwitchRow)[2];

    expect(followUp.props('modelValue')).toBe(true);
    followUp.vm.$emit('update:modelValue', false);
    expect(wrapper.emitted('update')[0][0]).toEqual({
      follow_up_questions: false,
    });
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

  it('passes balanced length, saved tone and their prompts to the editors', () => {
    const wrapper = mountSettings(
      { tone: 'custom', tone_prompt: 'Calm and warm.' },
      true,
      { prompt_presets: { tone: { friendly: 'Warm.' }, answer_length: {} } }
    );
    const [length, tone] = wrapper.findAllComponents(PresetPromptEditor);

    expect(length.props()).toMatchObject({
      selected: 'balanced',
      field: 'answer_length',
      promptField: 'answer_length_prompt',
    });
    expect(tone.props()).toMatchObject({
      selected: 'custom',
      customText: 'Calm and warm.',
      presetTexts: { friendly: 'Warm.' },
    });
    tone.vm.$emit('update', { tone: 'short' });
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

import { shallowMount } from '@vue/test-utils';
import RadioCard from 'dashboard/components-next/radioCard/RadioCard.vue';
import AssistantBehaviorSettings from './AssistantBehaviorSettings.vue';
import ReplyPreviewCard from './ReplyPreviewCard.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const mountSettings = config =>
  shallowMount(AssistantBehaviorSettings, {
    props: { assistant: { name: 'Luna', config } },
  });

describe('AssistantBehaviorSettings', () => {
  it('marks the saved tone and emits a new one', () => {
    const wrapper = mountSettings({ tone: 'professional' });
    const tones = wrapper.findAllComponents(RadioCard);

    expect(tones.map(tone => tone.props('isActive'))).toEqual([
      false,
      true,
      false,
    ]);
    tones[2].vm.$emit('select');
    expect(wrapper.emitted('update')[0][0]).toEqual({ tone: 'short' });
  });

  it('emits each reply card switch as its own config key', () => {
    const wrapper = mountSettings({ suggested_replies: true });
    const cards = wrapper.findAllComponents(ReplyPreviewCard);

    expect(cards[0].props('modelValue')).toBe(true);
    cards[1].vm.$emit('update:modelValue', true);
    cards[2].vm.$emit('update:modelValue', true);

    expect(wrapper.emitted('update')).toEqual([
      [{ product_cards: true }],
      [{ feature_citation: true }],
    ]);
  });
});

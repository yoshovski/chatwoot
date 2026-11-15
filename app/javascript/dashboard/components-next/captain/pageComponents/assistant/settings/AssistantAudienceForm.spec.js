import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import RadioCard from 'dashboard/components-next/radioCard/RadioCard.vue';
import SettingsSaveBar from './SettingsSaveBar.vue';
import SegmentPicker from 'dashboard/components-next/Contacts/Customers/SegmentPicker.vue';
import AssistantAudienceForm from './AssistantAudienceForm.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('./audience/useAudienceFilterTypes.js', () => ({
  useAudienceFilterTypes: () => ({ filterTypes: [] }),
}));

const mountComponent = () =>
  shallowMount(AssistantAudienceForm, {
    props: { assistant: { config: {} } },
    global: {
      stubs: {
        RadioCard: false,
        SettingsCard: false,
        SummaryRow: false,
        SettingsSaveBar: false,
      },
    },
  });

describe('AssistantAudienceForm', () => {
  it('does not submit a specific audience without conditions', async () => {
    const wrapper = mountComponent();

    wrapper
      .findAllComponents(RadioCard)
      .find(card => card.props('id') === 'specific')
      .vm.$emit('select', 'specific');
    await nextTick();
    const saveBar = wrapper.findComponent(SettingsSaveBar);
    saveBar.vm.$emit('save');
    await nextTick();

    expect(wrapper.emitted('submit')).toBeUndefined();
    expect(wrapper.text()).toContain(
      'CAPTAIN.ASSISTANTS.FORM.AUDIENCE.EMPTY_ERROR'
    );
  });
  it('submits a segment reference rather than copying its conditions', async () => {
    const wrapper = mountComponent();
    wrapper
      .findAllComponents(RadioCard)
      .find(card => card.props('id') === 'segment')
      .vm.$emit('select');
    await nextTick();
    wrapper
      .findComponent(SegmentPicker)
      .vm.$emit('update:modelValue', 'custom:42');
    await nextTick();
    wrapper.findComponent(SettingsSaveBar).vm.$emit('save');
    await nextTick();
    expect(wrapper.emitted('submit')[0][0].config.audience).toEqual({
      segment_id: 'custom:42',
    });
  });

  it('preserves an existing segment selection when editing', () => {
    const wrapper = shallowMount(AssistantAudienceForm, {
      props: { assistant: { config: { audience: { segment_id: 'leads' } } } },
      global: { stubs: { RadioCard: false } },
    });
    expect(wrapper.findComponent(SegmentPicker).props('modelValue')).toBe(
      'leads'
    );
  });
});

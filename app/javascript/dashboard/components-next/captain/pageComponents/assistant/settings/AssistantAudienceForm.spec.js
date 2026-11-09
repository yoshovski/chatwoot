import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import RadioCard from 'dashboard/components-next/radioCard/RadioCard.vue';
import SettingsSaveBar from './SettingsSaveBar.vue';
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

    wrapper.findAllComponents(RadioCard)[1].vm.$emit('select', 'specific');
    await nextTick();
    const saveBar = wrapper.findComponent(SettingsSaveBar);
    saveBar.vm.$emit('save');
    await nextTick();

    expect(wrapper.emitted('submit')).toBeUndefined();
    expect(wrapper.text()).toContain(
      'CAPTAIN.ASSISTANTS.FORM.AUDIENCE.EMPTY_ERROR'
    );
  });
});

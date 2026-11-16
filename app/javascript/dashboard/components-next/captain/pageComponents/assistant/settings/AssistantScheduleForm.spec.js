import { nextTick } from 'vue';
import { flushPromises, shallowMount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import RadioCard from 'dashboard/components-next/radioCard/RadioCard.vue';
import AssistantScheduleForm from './AssistantScheduleForm.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const mountComponent = (props = {}) =>
  shallowMount(AssistantScheduleForm, {
    props: {
      assistant: {
        id: 1,
        name: 'Octave',
        config: { response_window: 'always' },
      },
      ...props,
    },
    global: {
      stubs: {
        RadioCard: false,
        SettingsCard: false,
        SummaryRow: false,
        SettingsPanel: {
          template: '<div><slot /><slot name="footer" /></div>',
        },
        SettingsSaveBar: false,
      },
    },
  });

describe('AssistantScheduleForm', () => {
  it('renders radio cards with current schedule', () => {
    const wrapper = mountComponent();
    expect(wrapper.findAllComponents(RadioCard).length).toBe(3);
  });

  it('updates selection and submits updated response window', async () => {
    const save = vi.fn().mockResolvedValue(true);
    const wrapper = mountComponent({ save });

    const radioCards = wrapper.findAllComponents(RadioCard);
    expect(radioCards.length).toBe(3);

    // Select business hours
    radioCards[1].vm.$emit('select', 'business_hours');
    await nextTick();

    const saveBar = wrapper.findComponent({ name: 'SettingsSaveBar' });
    expect(saveBar.props('isDirty')).toBe(true);

    // Trigger save
    saveBar.vm.$emit('save');
    await nextTick();

    expect(save).toHaveBeenCalledWith({
      config: { response_window: 'business_hours' },
    });
  });

  it('retains the selection on failure and submits it just once on retry', async () => {
    const save = vi
      .fn()
      .mockResolvedValueOnce(false)
      .mockResolvedValueOnce(true);
    const assistant = {
      id: 1,
      name: 'Octave',
      config: { response_window: 'always' },
    };
    const wrapper = mountComponent({ assistant, save });
    const saveBar = wrapper.findComponent({ name: 'SettingsSaveBar' });
    wrapper
      .findAllComponents(RadioCard)[1]
      .vm.$emit('select', 'business_hours');
    await nextTick();

    saveBar.vm.$emit('save');
    saveBar.vm.$emit('save');
    await flushPromises();

    expect(save).toHaveBeenCalledTimes(1);
    expect(saveBar.props('isDirty')).toBe(true);
    expect(saveBar.props('error')).toBe(
      'CAPTAIN.ASSISTANTS.EDIT.ERROR_MESSAGE'
    );

    saveBar.vm.$emit('save');
    await flushPromises();
    await wrapper.setProps({
      assistant: {
        ...assistant,
        config: { response_window: 'business_hours' },
      },
    });
    expect(save).toHaveBeenCalledTimes(2);
    expect(wrapper.emitted('submit')).toBeUndefined();
    expect(saveBar.props('isDirty')).toBe(false);
    expect(saveBar.props('error')).toBe('');
  });
});

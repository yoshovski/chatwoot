import { nextTick } from 'vue';
import { flushPromises, shallowMount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import AssistantAfterChatForm from './AssistantAfterChatForm.vue';
import ChoiceCard from './ChoiceCard.vue';
import SettingsSaveBar from './SettingsSaveBar.vue';
import DurationSelect from './DurationSelect.vue';
import SettingsSwitchRow from './SettingsSwitchRow.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ isCloudFeatureEnabled: () => true }),
}));

vi.mock('dashboard/composables/useAdmin', () => ({
  useAdmin: () => ({ isAdmin: { value: true } }),
}));

const assistant = {
  config: {
    product_name: 'Chatwoot',
    handoff_message: 'I will connect you with the team.',
    resolution_message: 'I will close this conversation for now.',
    auto_resolve_mode: 'evaluated',
    auto_resolve_after: 75,
    send_inactivity_resolution_message: true,
    reply_labels: true,
    outcome_labels: false,
    feature_faq: true,
    feature_memory: false,
  },
};

const mountComponent = (save = vi.fn().mockResolvedValue()) =>
  shallowMount(AssistantAfterChatForm, {
    props: { assistant, save },
    global: {
      stubs: {
        Banner: false,
        SettingsCard: false,
        SettingsSplit: false,
      },
    },
  });

const submitForm = async wrapper => {
  wrapper.findComponent(SettingsSaveBar).vm.$emit('save');
  await flushPromises();
};

const savedPayload = wrapper => wrapper.props('save').mock.calls[0][0];
const goodbyeRows = wrapper =>
  wrapper
    .findAllComponents(SettingsSwitchRow)
    .filter(row =>
      row
        .props('title')
        .endsWith('INACTIVITY_RESOLUTION.RESOLUTION_MESSAGE.TITLE')
    );

describe('AssistantAfterChatForm', () => {
  it('shows the evaluated policy controls from the saved config', () => {
    const wrapper = mountComponent();
    const modeCards = wrapper.findAllComponents(ChoiceCard);

    expect(modeCards).toHaveLength(3);
    expect(
      modeCards.every(card => card.props('name') === 'auto-resolve-mode')
    ).toBe(true);
    expect(modeCards[0].props('isActive')).toBe(true);
    expect(wrapper.findAllComponents(DurationSelect)).toHaveLength(1);
    expect(goodbyeRows(wrapper)).toHaveLength(1);
    expect(wrapper.text()).toContain(
      'CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.REVIEW_AFTER'
    );
  });

  it('hides inactive actions and saves disabled mode without clearing settings', async () => {
    const wrapper = mountComponent();

    wrapper.findAllComponents(ChoiceCard)[2].vm.$emit('select');
    await nextTick();

    expect(wrapper.findAllComponents(DurationSelect)).toHaveLength(0);
    expect(goodbyeRows(wrapper)).toHaveLength(0);
    expect(wrapper.text()).toContain(
      'CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.PENDING_INFO'
    );

    await submitForm(wrapper);

    expect(savedPayload(wrapper)).toEqual({
      config: {
        ...assistant.config,
        auto_resolve_mode: 'disabled',
      },
    });
  });

  it('saves the evaluated policy timer', async () => {
    const wrapper = mountComponent();

    const durationSelects = wrapper.findAllComponents(DurationSelect);
    expect(durationSelects).toHaveLength(1);

    durationSelects[0].vm.$emit('update:modelValue', 130);
    await nextTick();
    await submitForm(wrapper);

    expect(savedPayload(wrapper)).toEqual({
      config: {
        ...assistant.config,
        auto_resolve_after: 130,
      },
    });
  });

  it('saves the label and learning switches with the other settings', async () => {
    const wrapper = mountComponent();
    const rows = wrapper
      .findAllComponents(SettingsSwitchRow)
      .filter(
        row =>
          !row
            .props('title')
            .endsWith('INACTIVITY_RESOLUTION.RESOLUTION_MESSAGE.TITLE')
      );
    const byTitle = suffix =>
      wrapper
        .findAllComponents(SettingsSwitchRow)
        .find(row => row.props('title').endsWith(suffix));

    expect(rows).toHaveLength(4);
    byTitle('OUTCOME_LABELS.TITLE').vm.$emit('update:modelValue', true);
    byTitle('MEMORIES.TITLE').vm.$emit('update:modelValue', true);
    await nextTick();
    await submitForm(wrapper);

    expect(savedPayload(wrapper)).toEqual({
      config: {
        ...assistant.config,
        outcome_labels: true,
        feature_memory: true,
      },
    });
  });

  it('shows the save bar only after a change and discards it', async () => {
    const wrapper = mountComponent();
    const saveBar = () => wrapper.findComponent(SettingsSaveBar);

    expect(saveBar().props('isDirty')).toBe(false);

    wrapper.findAllComponents(ChoiceCard)[1].vm.$emit('select');
    await nextTick();
    expect(saveBar().props('isDirty')).toBe(true);

    saveBar().vm.$emit('discard');
    await nextTick();
    expect(saveBar().props('isDirty')).toBe(false);
    expect(wrapper.findAllComponents(ChoiceCard)[0].props('isActive')).toBe(
      true
    );
  });

  it('shows the warning in always resolve mode', async () => {
    const wrapper = mountComponent();

    wrapper.findAllComponents(ChoiceCard)[1].vm.$emit('select');
    await nextTick();

    expect(wrapper.findAllComponents(DurationSelect)).toHaveLength(1);
    expect(goodbyeRows(wrapper)).toHaveLength(1);
    expect(wrapper.text()).toContain(
      'CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.ALWAYS_WARNING'
    );
  });
});

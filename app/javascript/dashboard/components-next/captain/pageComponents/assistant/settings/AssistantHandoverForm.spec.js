import { nextTick, ref } from 'vue';
import { flushPromises, shallowMount } from '@vue/test-utils';
import AssistantHandoverForm from './AssistantHandoverForm.vue';
import SettingsSwitchRow from './SettingsSwitchRow.vue';
import SettingsSaveBar from './SettingsSaveBar.vue';
import HandoffFlow from './HandoffFlow.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Editor from 'dashboard/components-next/Editor/Editor.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ isCloudFeatureEnabled: () => true }),
}));

vi.mock('dashboard/composables/useAdmin', () => ({
  useAdmin: () => ({ isAdmin: ref(true) }),
}));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: vi.fn() }),
  useMapGetter: () => ref([]),
}));

const assistant = {
  name: 'Luna',
  config: {
    product_name: 'Acme',
    handoff_message: 'A teammate will reply here.',
    continue_while_waiting: false,
    handoff_safety_net: true,
    handoff_fallback_team_id: 4,
    feature_faq: true,
  },
};

const mountForm = () =>
  shallowMount(AssistantHandoverForm, {
    props: { assistant, save: vi.fn().mockResolvedValue() },
    global: { stubs: { SettingsCard: false, SettingsSplit: false } },
  });

describe('AssistantHandoverForm', () => {
  it('saves only the handover settings and keeps the rest of the config', async () => {
    const wrapper = mountForm();

    wrapper
      .findAllComponents(SettingsSwitchRow)[0]
      .vm.$emit('update:modelValue', true);
    await nextTick();
    expect(wrapper.findComponent(SettingsSaveBar).props('isDirty')).toBe(true);
    expect(wrapper.findComponent(HandoffFlow).props('keepHelping')).toBe(true);

    wrapper.findComponent(SettingsSaveBar).vm.$emit('save');
    await flushPromises();

    expect(wrapper.props('save')).toHaveBeenCalledWith({
      config: {
        ...assistant.config,
        continue_while_waiting: true,
        handoff_when_online: 'transfer',
        handoff_when_offline: 'transfer',
        offline_handoff_message: '',
        no_handoff_message: '',
        handoff_rules: [],
        handoff_fallback_agent_id: null,
        handoff_fallback_team_id: 4,
      },
    });
  });

  it('asks for the keep message only when the assistant keeps conversations', async () => {
    const wrapper = mountForm();
    const editorLabels = () =>
      wrapper.findAllComponents(Editor).map(editor => editor.props('label'));

    expect(editorLabels()).not.toContain(
      'CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.KEEP_MESSAGE.LABEL'
    );
    wrapper.findAllComponents(Select)[1].vm.$emit('update:modelValue', 'keep');
    await nextTick();

    expect(editorLabels()).toContain(
      'CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.KEEP_MESSAGE.LABEL'
    );
    expect(editorLabels()).not.toContain(
      'CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.OFFLINE_MESSAGE.LABEL'
    );
    expect(wrapper.findComponent(HandoffFlow).props('whenOffline')).toBe(
      'keep'
    );
  });
});

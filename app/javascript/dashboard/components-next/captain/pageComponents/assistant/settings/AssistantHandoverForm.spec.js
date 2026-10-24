import { nextTick, ref } from 'vue';
import { flushPromises, shallowMount } from '@vue/test-utils';
import AssistantHandoverForm from './AssistantHandoverForm.vue';
import SettingsSwitchRow from './SettingsSwitchRow.vue';
import SettingsSaveBar from './SettingsSaveBar.vue';
import HandoffFlow from './HandoffFlow.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Editor from 'dashboard/components-next/Editor/Editor.vue';
import Input from 'dashboard/components-next/input/Input.vue';

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

    const emailOption = wrapper
      .findAllComponents(SettingsSwitchRow)
      .find(row => row.props('title').endsWith('CONTACT_FORM.EMAIL'));
    expect(emailOption.props('modelValue')).toBe(true);
    expect(emailOption.props('disabled')).toBe(true);

    wrapper
      .findAllComponents(SettingsSwitchRow)
      .find(row => row.props('title').endsWith('KEEP_HELPING.TITLE'))
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
        handoff_form_message: '',
        handoff_collect_name: true,
        handoff_collect_phone: false,
        handoff_fallback_agent_id: null,
        handoff_fallback_team_id: 4,
      },
    });
  });

  it('saves the form message and selected fields and restores them on discard', async () => {
    const wrapper = mountForm();
    await wrapper
      .find('textarea')
      .setValue('  Leave your details for our team.  ');
    const rows = wrapper.findAllComponents(SettingsSwitchRow);
    rows
      .find(row => row.props('title').endsWith('CONTACT_FORM.NAME'))
      .vm.$emit('update:modelValue', false);
    rows
      .find(row => row.props('title').endsWith('CONTACT_FORM.PHONE'))
      .vm.$emit('update:modelValue', true);
    await nextTick();

    wrapper.findComponent(SettingsSaveBar).vm.$emit('save');
    await flushPromises();
    expect(wrapper.props('save')).toHaveBeenCalledWith({
      config: expect.objectContaining({
        handoff_form_message: 'Leave your details for our team.',
        handoff_collect_name: false,
        handoff_collect_phone: true,
      }),
    });

    wrapper.findComponent(SettingsSaveBar).vm.$emit('discard');
    await nextTick();
    expect(wrapper.find('textarea').element.value).toBe('');
    expect(wrapper.findComponent(SettingsSaveBar).props('isDirty')).toBe(false);
  });

  it('keeps every conversation and points to email when there is no live team', async () => {
    const wrapper = mountForm();

    wrapper
      .findComponent(Input)
      .vm.$emit('update:modelValue', 'help@acme.test');
    await nextTick();
    await wrapper.find('form').trigger('submit');
    wrapper.findComponent(SettingsSaveBar).vm.$emit('save');
    await flushPromises();

    expect(wrapper.props('save')).toHaveBeenCalledWith({
      config: expect.objectContaining({
        handoff_when_online: 'keep',
        handoff_when_offline: 'keep',
        no_handoff_message:
          'CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.EMAIL_ONLY.MESSAGE',
      }),
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

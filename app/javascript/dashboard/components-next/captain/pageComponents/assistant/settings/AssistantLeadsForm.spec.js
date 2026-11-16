import { ref } from 'vue';
import { flushPromises, shallowMount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import AssistantLeadsForm from './AssistantLeadsForm.vue';
import SettingsSaveBar from './SettingsSaveBar.vue';
import LeadStepAsk from './leads/LeadStepAsk.vue';
import LeadStepWhen from './leads/LeadStepWhen.vue';
import LeadStepWhere from './leads/LeadStepWhere.vue';
import { useLeadSettings } from './leads/useLeadSettings';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn() }) }));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: vi.fn() }),
}));
vi.mock('dashboard/api/teams', () => ({
  default: { get: vi.fn().mockResolvedValue({ data: [] }) },
}));
vi.mock('./useLeadSetup', () => ({
  useLeadSetup: () => ({
    captureScenario: ref({ title: 'Capture lead' }),
    existingScenario: ref({ title: 'Capture lead' }),
    hubspotState: ref('not_connected'),
    loading: ref(false),
    scenarioError: ref(false),
    refresh: vi.fn(),
  }),
}));
const config = {
  leads_enabled: true,
  lead_guided_setup: true,
  lead_trigger: 'Wholesale enquiries',
  lead_instructions: 'Answer first',
  lead_max_questions: 2,
  lead_handoff_capture_enabled: true,
  lead_notification_team_id: null,
  published_pricing_enabled: true,
  lead_fields: [{ key: 'company', label: 'Company' }],
  lead_types: [{ name: 'wholesale', rule: 'Buying in bulk' }],
};
const Capture = {
  setup: () => ({ lead: useLeadSettings() }),
  template: '<div />',
};
const global = {
  stubs: {
    KeepAlive: false,
    SettingsSplit: { template: '<div><slot /><slot name="preview" /></div>' },
    LeadWidgetPreview: Capture,
  },
};

describe('Lead setup stepper', () => {
  it('opens each step and saves the existing settings unchanged', async () => {
    const save = vi.fn().mockResolvedValue(true);
    const wrapper = shallowMount(AssistantLeadsForm, {
      props: { assistant: { id: 1, config }, save },
      global,
    });
    await flushPromises();
    expect(wrapper.findComponent(LeadStepAsk).exists()).toBe(true);
    await wrapper.findAll('ol button')[1].trigger('click');
    expect(wrapper.findComponent(LeadStepWhen).exists()).toBe(true);
    await wrapper.findAll('ol button')[2].trigger('click');
    expect(wrapper.findComponent(LeadStepWhere).exists()).toBe(true);
    wrapper.findComponent(SettingsSaveBar).vm.$emit('save');
    await flushPromises();
    expect(save).toHaveBeenCalledWith({ config });
    wrapper.unmount();
  });

  it('discards draft edits without mutating the saved assistant', async () => {
    const wrapper = shallowMount(AssistantLeadsForm, {
      props: { assistant: { id: 1, config }, save: vi.fn() },
      global,
    });
    const state = wrapper.findComponent(Capture).vm.lead;
    state.settings.value.lead_fields[0].label = 'Changed';
    expect(config.lead_fields[0].label).toBe('Company');
    wrapper.findComponent(SettingsSaveBar).vm.$emit('discard');
    await flushPromises();
    expect(state.settings.value.lead_fields[0].label).toBe('Company');
    wrapper.unmount();
  });

  it('returns to What to ask when invalid fields are saved from another step', async () => {
    const save = vi.fn();
    const wrapper = shallowMount(AssistantLeadsForm, {
      props: { assistant: { id: 1, config }, save },
      global,
    });
    wrapper.findComponent(Capture).vm.lead.settings.value.lead_fields[0].key =
      'invalid key';
    await wrapper.findAll('ol button')[2].trigger('click');
    wrapper.findComponent(SettingsSaveBar).vm.$emit('save');
    await flushPromises();
    expect(wrapper.findComponent(LeadStepAsk).exists()).toBe(true);
    expect(wrapper.find('[role="alert"]').exists()).toBe(true);
    expect(save).not.toHaveBeenCalled();
    wrapper.unmount();
  });
  it('saves paused edits without activating and enables only through the explicit action', async () => {
    const save = vi.fn().mockResolvedValue(true);
    const wrapper = shallowMount(AssistantLeadsForm, {
      props: {
        assistant: { id: 1, config: { ...config, leads_enabled: false } },
        save,
      },
      global,
    });
    await flushPromises();
    const state = wrapper.findComponent(Capture).vm.lead;
    state.settings.value.lead_trigger = 'New trigger';
    wrapper.findComponent(SettingsSaveBar).vm.$emit('save');
    await flushPromises();
    expect(save.mock.calls[0][0].config).toMatchObject({
      leads_enabled: false,
      lead_trigger: 'New trigger',
    });
    const enable = wrapper
      .findAll('button-stub')
      .find(button =>
        button.attributes('label')?.endsWith('ACTIVATION.ENABLE')
      );
    await enable.trigger('click');
    await flushPromises();
    expect(save.mock.calls[1][0].config.leads_enabled).toBe(true);
    expect(state.settings.value.leads_enabled).toBe(true);
    expect(state.fieldKeyLocked(state.settings.value.lead_fields[0])).toBe(
      true
    );
    wrapper.unmount();
  });

  it('keeps paused state and delivery edits when saving fails', async () => {
    const save = vi.fn().mockResolvedValue(false);
    const wrapper = shallowMount(AssistantLeadsForm, {
      props: {
        assistant: { id: 1, config: { ...config, leads_enabled: false } },
        save,
      },
      global,
    });
    await flushPromises();
    const state = wrapper.findComponent(Capture).vm.lead;
    state.settings.value.lead_notification_team_id = 9;
    wrapper.findComponent(SettingsSaveBar).vm.$emit('save');
    await flushPromises();
    expect(state.settings.value.lead_notification_team_id).toBe(9);
    expect(state.settings.value.leads_enabled).toBe(false);
    expect(state.isDirty.value).toBe(true);
    wrapper.unmount();
  });

  it('rejects activation without a lead type and shows the relevant step', async () => {
    const save = vi.fn();
    const wrapper = shallowMount(AssistantLeadsForm, {
      props: {
        assistant: {
          id: 1,
          config: { ...config, leads_enabled: false, lead_types: [] },
        },
        save,
      },
      global,
    });
    await flushPromises();
    await wrapper.findAll('ol button')[2].trigger('click');
    const enable = wrapper
      .findAll('button-stub')
      .find(button =>
        button.attributes('label')?.endsWith('ACTIVATION.ENABLE')
      );
    await enable.trigger('click');
    await flushPromises();
    expect(wrapper.findComponent(LeadStepAsk).exists()).toBe(true);
    expect(wrapper.find('[role="alert"]').exists()).toBe(true);
    expect(save).not.toHaveBeenCalled();
    wrapper.unmount();
  });

  it('retains the saved capture state when activation fails', async () => {
    const save = vi.fn().mockResolvedValue(false);
    const wrapper = shallowMount(AssistantLeadsForm, {
      props: {
        assistant: { id: 1, config: { ...config, leads_enabled: false } },
        save,
      },
      global,
    });
    await flushPromises();
    const enable = wrapper
      .findAll('button-stub')
      .find(button =>
        button.attributes('label')?.endsWith('ACTIVATION.ENABLE')
      );
    await enable.trigger('click');
    await flushPromises();
    expect(save.mock.calls[0][0].config.leads_enabled).toBe(true);
    expect(
      wrapper.findComponent(Capture).vm.lead.settings.value.leads_enabled
    ).toBe(false);
    wrapper.unmount();
  });
});

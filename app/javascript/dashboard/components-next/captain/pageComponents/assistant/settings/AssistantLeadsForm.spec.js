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
});

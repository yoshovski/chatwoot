import { nextTick, ref } from 'vue';
import { flushPromises, shallowMount } from '@vue/test-utils';
import Button from 'dashboard/components-next/button/Button.vue';
import AssistantHandoverForm from './AssistantHandoverForm.vue';
import SettingsSwitchRow from './SettingsSwitchRow.vue';

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
    props: { assistant },
    global: { stubs: { SettingsCard: false } },
  });

describe('AssistantHandoverForm', () => {
  it('saves only the handover settings and keeps the rest of the config', async () => {
    const wrapper = mountForm();

    wrapper
      .findAllComponents(SettingsSwitchRow)[0]
      .vm.$emit('update:modelValue', true);
    await nextTick();
    wrapper.findComponent(Button).vm.$emit('click');
    await flushPromises();

    expect(wrapper.emitted('submit')[0][0]).toEqual({
      config: {
        ...assistant.config,
        continue_while_waiting: true,
        handoff_fallback_agent_id: null,
        handoff_fallback_team_id: 4,
      },
    });
  });
});

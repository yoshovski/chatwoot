import { nextTick } from 'vue';
import { flushPromises, shallowMount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import AssistantConversationForm from './AssistantConversationForm.vue';
import ChoiceCard from './ChoiceCard.vue';
import SettingsSaveBar from './SettingsSaveBar.vue';
import SettingsSwitchRow from './SettingsSwitchRow.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const assistant = {
  name: 'Ava',
  config: {
    product_name: 'Acme',
    agent_role: 'support',
    visitor_audience: 'customers',
    greeting_mode: 'off',
    welcome_message: '',
    separate_follow_up: true,
  },
};

const mountComponent = (config = {}, save = vi.fn().mockResolvedValue()) =>
  shallowMount(AssistantConversationForm, {
    props: {
      assistant: { ...assistant, config: { ...assistant.config, ...config } },
      save,
    },
    global: {
      stubs: {
        SettingsCard: false,
        SettingsSplit: false,
        AssistantChatPreview: false,
        Avatar: true,
      },
    },
  });

const cards = (wrapper, name) =>
  wrapper
    .findAllComponents(ChoiceCard)
    .filter(card => card.props('name') === name);

const select = async (wrapper, name, value) => {
  cards(wrapper, name)
    .find(card => card.props('value') === value)
    .vm.$emit('select');
  await nextTick();
};

const submit = async wrapper => {
  wrapper.findComponent(SettingsSaveBar).vm.$emit('save');
  await flushPromises();
};

const previewBubbles = wrapper =>
  wrapper
    .findAll('[data-test-id="preview-agent-bubble"]')
    .map(bubble => bubble.text());

describe('AssistantConversationForm', () => {
  it('shows the saved choices', () => {
    const wrapper = mountComponent({ agent_role: 'sales' });

    expect(cards(wrapper, 'agent-role')).toHaveLength(4);
    expect(cards(wrapper, 'visitor-audience')).toHaveLength(3);
    expect(cards(wrapper, 'greeting-mode')).toHaveLength(3);
    expect(
      cards(wrapper, 'agent-role')
        .find(card => card.props('isActive'))
        .props('value')
    ).toBe('sales');
    expect(wrapper.findComponent(SettingsSaveBar).props('isDirty')).toBe(false);
  });

  it('saves role, audience, greeting and the follow-up switch with the rest of the config', async () => {
    const wrapper = mountComponent();

    await select(wrapper, 'agent-role', 'custom');
    wrapper
      .find('[data-test-id="role-prompt"]')
      .findComponent(TextArea)
      .vm.$emit('update:modelValue', '  You help gardeners plan beds.  ');
    await select(wrapper, 'visitor-audience', 'detect');
    await select(wrapper, 'greeting-mode', 'fixed');
    wrapper
      .find('[data-test-id="welcome-message"]')
      .findComponent(TextArea)
      .vm.$emit('update:modelValue', 'Hi {{contact.first_name}}!');
    wrapper
      .findComponent(SettingsSwitchRow)
      .vm.$emit('update:modelValue', false);
    await nextTick();

    expect(wrapper.findComponent(SettingsSaveBar).props('isDirty')).toBe(true);
    await submit(wrapper);

    expect(wrapper.props('save')).toHaveBeenCalledWith({
      config: {
        product_name: 'Acme',
        agent_role: 'custom',
        agent_role_prompt: 'You help gardeners plan beds.',
        visitor_audience: 'detect',
        greeting_mode: 'fixed',
        welcome_message: 'Hi {{contact.first_name}}!',
        separate_follow_up: false,
      },
    });
  });

  it('asks for the custom role and the welcome message before saving', async () => {
    const wrapper = mountComponent();

    await select(wrapper, 'agent-role', 'custom');
    await select(wrapper, 'greeting-mode', 'fixed');
    await submit(wrapper);

    expect(wrapper.props('save')).not.toHaveBeenCalled();
    expect(
      wrapper
        .find('[data-test-id="role-prompt"]')
        .findComponent(TextArea)
        .props('message')
    ).toBe('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.ROLE.CUSTOM_REQUIRED');
  });

  it('previews the reply shape for the choices', async () => {
    const wrapper = mountComponent();

    expect(previewBubbles(wrapper)).toEqual([
      'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.PREVIEW.ANSWER_CUSTOMERS',
      'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.PREVIEW.FOLLOW_UP_SUPPORT',
    ]);

    await select(wrapper, 'agent-role', 'sales');
    await select(wrapper, 'visitor-audience', 'prospects');
    await select(wrapper, 'greeting-mode', 'ai');
    wrapper
      .findComponent(SettingsSwitchRow)
      .vm.$emit('update:modelValue', false);
    await nextTick();

    expect(previewBubbles(wrapper)).toEqual([
      'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.PREVIEW.GREETING CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.PREVIEW.ANSWER_PROSPECTS CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.PREVIEW.FOLLOW_UP_SALES',
    ]);
  });

  it('previews a fixed welcome as its own bubble with a sample first name', async () => {
    const wrapper = mountComponent({
      greeting_mode: 'fixed',
      welcome_message: 'Hi {{ contact.first_name }}!',
    });

    expect(previewBubbles(wrapper)[0]).toBe(
      'Hi CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.PREVIEW.FIRST_NAME!'
    );
  });
});

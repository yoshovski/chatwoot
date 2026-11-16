import { mount, shallowMount } from '@vue/test-utils';
import AgentMessage from '../AgentMessage.vue';
import { previewSender } from 'widget/helpers/notificationPreview';

const maliciousName =
  '<img src="https://example.com/tracker.png" onerror="alert(1)">Agent';
const maliciousCompanyName = '<strong>Example Company</strong>';

const channelConfig = {
  avatarUrl: '',
  enabledFeatures: [],
  websiteName: maliciousCompanyName,
};

describe('agent identity rendering', () => {
  beforeEach(() => {
    window.chatwootWebChannel = channelConfig;
  });

  afterEach(() => {
    delete window.chatwootWebChannel;
  });

  it('renders the agent name as plain text beside widget messages', () => {
    const wrapper = shallowMount(AgentMessage, {
      props: {
        message: {
          id: 1,
          attachments: [],
          content: 'Hello',
          content_attributes: {},
          content_type: 'text',
          message_type: 1,
          sender: {
            available_name: maliciousName,
            avatar_url: '',
          },
          showAvatar: true,
        },
      },
      // AgentMessage reads the conversation's last message to decide whether a message's reply
      // choices are still live.
      global: {
        mocks: {
          $store: { getters: { 'conversation/getLastReplyMessage': {} } },
        },
      },
    });
    const agentName = wrapper.find('.agent-name');

    expect(agentName.text()).toBe(maliciousName);
    expect(agentName.find('img').exists()).toBe(false);
    expect(agentName.html()).toContain('&lt;img');
  });

  it('renders custom captain assistant name and avatar beside widget messages', () => {
    const wrapper = shallowMount(AgentMessage, {
      props: {
        message: {
          id: 2,
          attachments: [],
          content: 'Hello from assistant',
          content_attributes: {},
          content_type: 'text',
          message_type: 1,
          sender: {
            available_name: 'Custom Assistant',
            avatar_url: 'https://example.com/custom-assistant.png',
            type: 'captain_assistant',
          },
          showAvatar: true,
        },
      },
      global: {
        mocks: {
          $store: { getters: { 'conversation/getLastReplyMessage': {} } },
          $t: text => text,
        },
      },
    });

    expect(wrapper.vm.agentName).toBe('Custom Assistant');
    expect(wrapper.vm.avatarUrl).toBe(
      'https://example.com/custom-assistant.png'
    );
  });

  it('falls back to captain logo when captain assistant has no custom avatar beside widget messages', () => {
    const wrapper = shallowMount(AgentMessage, {
      props: {
        message: {
          id: 3,
          attachments: [],
          content: 'Hello from assistant',
          content_attributes: {},
          content_type: 'text',
          message_type: 1,
          sender: {
            available_name: 'Default Assistant',
            avatar_url: '',
            type: 'captain_assistant',
          },
          showAvatar: true,
        },
      },
      global: {
        mocks: {
          $store: { getters: { 'conversation/getLastReplyMessage': {} } },
          $t: text => text,
        },
      },
    });

    expect(wrapper.vm.agentName).toBe('Default Assistant');
    expect(wrapper.vm.avatarUrl).toBe(
      '/assets/images/dashboard/captain/ai-agent-avatar.svg'
    );
  });
});

describe('closed-chat card sender', () => {
  const channel = {
    websiteName: 'Scanixx',
    avatarUrl: '/inbox.png',
    enabledFeatures: [],
  };

  it('uses the custom assistant name and avatar', () => {
    expect(
      previewSender(
        {
          available_name: 'Custom Assistant',
          avatar_url: 'https://example.com/custom-assistant.png',
          type: 'captain_assistant',
        },
        channel,
        'Bot'
      )
    ).toEqual({
      name: 'Custom Assistant',
      avatarUrl: 'https://example.com/custom-assistant.png',
    });
  });

  it('falls back to the captain logo when the assistant has no avatar', () => {
    expect(
      previewSender(
        {
          available_name: 'Default Assistant',
          avatar_url: '',
          type: 'captain_assistant',
        },
        channel,
        'Bot'
      ).avatarUrl
    ).toBe('/assets/images/dashboard/captain/ai-agent-avatar.svg');
  });

  it('uses the inbox name and avatar for a bot when the inbox asks for it', () => {
    expect(
      previewSender(
        null,
        { ...channel, enabledFeatures: ['use_inbox_avatar_for_bot'] },
        'Bot'
      )
    ).toEqual({
      name: 'Scanixx',
      avatarUrl: '/inbox.png',
    });
  });
});

describe('AI agent messages', () => {
  const mountWithSender = sender =>
    mount(AgentMessage, {
      props: {
        message: {
          id: 1,
          content: 'Hello',
          content_attributes: {},
          content_type: 'text',
          message_type: 1,
          sender,
          showAvatar: true,
        },
      },
      global: {
        mocks: {
          $store: { getters: { 'conversation/getLastReplyMessage': {} } },
        },
        stubs: { Avatar: true },
        directives: { dompurifyHtml: () => {} },
      },
    });

  beforeEach(() => {
    window.chatwootWebChannel = channelConfig;
  });

  afterEach(() => {
    delete window.chatwootWebChannel;
  });

  it.each(['captain_assistant', 'user', 'agent_bot'])(
    'shows only the sender name for %s senders',
    type => {
      const wrapper = mountWithSender({ type, name: 'Sam', avatar_url: '' });

      expect(wrapper.find('.agent-name').text()).toBe('Sam');
    }
  );
});

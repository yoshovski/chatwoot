import { mount, shallowMount } from '@vue/test-utils';
import AgentMessage from '../AgentMessage.vue';
import UnreadMessage from '../UnreadMessage.vue';

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
          $store: { getters: { 'conversation/getLastMessage': {} } },
        },
      },
    });
    const agentName = wrapper.find('.agent-name');

    expect(agentName.text()).toBe(maliciousName);
    expect(agentName.find('img').exists()).toBe(false);
    expect(agentName.html()).toContain('&lt;img');
  });

  it('renders agent and company names as plain text in unread messages', () => {
    const wrapper = mount(UnreadMessage, {
      props: {
        message: 'Hello',
        showSender: true,
        sender: {
          available_name: maliciousName,
          avatar_url: '',
        },
      },
      global: {
        stubs: { Avatar: true },
        directives: {
          dompurifyHtml: (element, binding) => {
            element.textContent = binding.value;
          },
        },
      },
    });
    const agentName = wrapper.find('.agent--name');
    const companyName = wrapper.find('.company--name');

    expect(agentName.text()).toBe(maliciousName);
    expect(agentName.find('img').exists()).toBe(false);
    expect(companyName.text()).toContain(maliciousCompanyName);
    expect(companyName.find('strong').exists()).toBe(false);
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
          $store: { getters: { 'conversation/getLastMessage': {} } },
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
          $store: { getters: { 'conversation/getLastMessage': {} } },
          $t: text => text,
        },
      },
    });

    expect(wrapper.vm.agentName).toBe('Default Assistant');
    expect(wrapper.vm.avatarUrl).toBe(
      '/assets/images/dashboard/captain/ai-agent-avatar.svg'
    );
  });

  it('renders custom captain assistant name and avatar in unread messages', () => {
    const wrapper = mount(UnreadMessage, {
      props: {
        message: 'Hello from unread assistant',
        showSender: true,
        sender: {
          available_name: 'Custom Assistant',
          avatar_url: 'https://example.com/custom-assistant.png',
          type: 'captain_assistant',
        },
      },
      global: {
        stubs: { Avatar: true },
        directives: {
          dompurifyHtml: (element, binding) => {
            element.textContent = binding.value;
          },
        },
        mocks: {
          $t: text => text,
        },
      },
    });

    expect(wrapper.vm.agentName).toBe('Custom Assistant');
    expect(wrapper.vm.avatarUrl).toBe(
      'https://example.com/custom-assistant.png'
    );
  });

  it('falls back to captain logo when captain assistant has no custom avatar in unread messages', () => {
    const wrapper = mount(UnreadMessage, {
      props: {
        message: 'Hello from unread assistant',
        showSender: true,
        sender: {
          available_name: 'Default Assistant',
          avatar_url: '',
          type: 'captain_assistant',
        },
      },
      global: {
        stubs: { Avatar: true },
        directives: {
          dompurifyHtml: (element, binding) => {
            element.textContent = binding.value;
          },
        },
        mocks: {
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

describe('AI badge', () => {
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
        mocks: { $store: { getters: { 'conversation/getLastMessage': {} } } },
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

  it('shows next to the name of an AI assistant', () => {
    const wrapper = mountWithSender({
      type: 'captain_assistant',
      name: 'Luna',
      avatar_url: '',
    });

    expect(wrapper.find('.agent-name').text()).toContain('Luna');
    expect(wrapper.find('.agent-name [role="img"]').exists()).toBe(true);
  });

  it.each(['user', 'agent_bot'])('is not shown for %s senders', type => {
    const wrapper = mountWithSender({ type, name: 'Sam', avatar_url: '' });

    expect(wrapper.find('.agent-name').text()).toBe('Sam');
    expect(wrapper.find('[role="img"]').exists()).toBe(false);
  });
});

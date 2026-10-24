import { mount } from '@vue/test-utils';
import AgentMessageBubble from '../AgentMessageBubble.vue';

const mountBubble = message =>
  mount(AgentMessageBubble, {
    props: {
      message,
      contentType: 'input_select',
      messageType: 1,
      messageId: 1,
      messageContentAttributes: {
        items: [{ title: 'Track order', value: 'Where is my order?' }],
      },
    },
    global: {
      mocks: { $t: key => key, $store: { dispatch: vi.fn() } },
      directives: {
        dompurifyHtml: (element, binding) => {
          element.innerHTML = binding.value;
        },
      },
    },
  });

describe('AgentMessageBubble with suggestion buttons', () => {
  it('shows links in the reply and hides expired suggestion buttons', async () => {
    const wrapper = mountBubble(
      'Read the [shipping guide](https://example.com/shipping).'
    );

    const link = wrapper.find('a[href="https://example.com/shipping"]');
    expect(link.exists()).toBe(true);
    expect(link.text()).toBe('shipping guide');
    expect(wrapper.text()).toContain('Track order');
    await wrapper.setProps({ hideOptions: true });
    expect(wrapper.text()).not.toContain('Track order');
    expect(wrapper.find('.option-button').exists()).toBe(false);
    expect(
      wrapper.find('a[href="https://example.com/shipping"]').exists()
    ).toBe(true);
  });

  it('renders knowledge videos and screenshots alongside the answer', () => {
    const wrapper = mountBubble(
      'Here is how.\n[Watch: setup](https://www.youtube.com/watch?v=abc123xyz)\n' +
        '[Screenshot: The service account permissions](https://example.com/setup.png)'
    );

    expect(wrapper.find('.message-content').text()).toBe('Here is how.');
    expect(wrapper.findComponent({ name: 'MessageVideo' }).exists()).toBe(true);
    expect(wrapper.find('figure img').attributes('src')).toBe(
      'https://example.com/setup.png'
    );
    expect(wrapper.find('figure img').attributes('alt')).toBe(
      'The service account permissions'
    );
  });
});

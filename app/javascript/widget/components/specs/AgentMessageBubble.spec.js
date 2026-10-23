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
  it('shows links in the reply above the buttons', () => {
    const wrapper = mountBubble(
      'Read the [shipping guide](https://example.com/shipping).'
    );

    const link = wrapper.find('a[href="https://example.com/shipping"]');
    expect(link.exists()).toBe(true);
    expect(link.text()).toBe('shipping guide');
    expect(wrapper.text()).toContain('Track order');
  });

  it('plays a video link as a card instead of a text line', () => {
    const wrapper = mountBubble(
      'Here is how.\n[Watch: setup](https://www.youtube.com/watch?v=abc123xyz)'
    );

    expect(wrapper.find('.message-content').text()).toBe('Here is how.');
    expect(wrapper.findComponent({ name: 'MessageVideo' }).exists()).toBe(true);
  });
});

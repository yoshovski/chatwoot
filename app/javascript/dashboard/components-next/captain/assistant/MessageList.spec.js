import { mount } from '@vue/test-utils';
import MessageList from './MessageList.vue';

vi.mock('shared/composables/useMessageFormatter', () => ({
  useMessageFormatter: () => ({ formatMessage: content => content }),
}));

const mountList = (messages, props = {}) =>
  mount(MessageList, {
    props: { messages, ...props },
    global: {
      directives: {
        dompurifyHtml: (el, { value }) => {
          el.innerHTML = value;
        },
      },
      stubs: { Avatar: true },
    },
  });

const userTurn = { sender: 'user', content: 'Hi' };
const assistantTurn = extra => ({
  sender: 'assistant',
  content: 'Hello there',
  ...extra,
});

describe('MessageList', () => {
  it('renders the answer text of a result without a customer view', () => {
    const wrapper = mountList([userTurn, assistantTurn()]);

    expect(wrapper.get('[data-test="playground-text"]').text()).toBe(
      'Hello there'
    );
  });

  it('renders suggestion buttons and sends the clicked title', async () => {
    const wrapper = mountList([
      userTurn,
      assistantTurn({
        messages: [
          {
            content: 'Hello there',
            content_type: 'input_select',
            content_attributes: {
              items: [
                { title: 'Track order', value: 'Track order' },
                { title: 'Return item', value: 'Return item' },
              ],
            },
          },
        ],
      }),
    ]);

    const buttons = wrapper.findAll('li button');
    expect(buttons.map(button => button.text())).toEqual([
      'Track order',
      'Return item',
    ]);

    await buttons[1].trigger('click');

    expect(wrapper.emitted('selectOption')).toEqual([
      [{ index: 1, title: 'Return item' }],
    ]);
  });

  it('disables the buttons of a reply that is no longer the latest or already answered', () => {
    const turn = assistantTurn({
      messages: [
        {
          content: 'Pick one',
          content_type: 'input_select',
          content_attributes: { items: [{ title: 'A', value: 'A' }] },
        },
      ],
    });

    const older = mountList([turn, userTurn]);
    const answered = mountList([{ ...turn, selectedOption: 'A' }]);

    expect(older.get('li button').attributes()).toHaveProperty('disabled');
    expect(answered.get('li button').attributes()).toHaveProperty('disabled');
  });

  it('renders product cards with links that open in a new tab', () => {
    const wrapper = mountList([
      assistantTurn({
        messages: [
          { content: 'Hello there', content_type: 'text' },
          {
            content: 'Spraying Drone',
            content_type: 'cards',
            content_attributes: {
              items: [
                {
                  title: 'Spraying Drone',
                  description: '19999 EUR',
                  media_url: 'https://cdn.example.com/drone.jpg',
                  actions: [
                    {
                      type: 'link',
                      text: 'View product',
                      uri: 'https://shop.example.com/products/drone',
                    },
                  ],
                },
              ],
            },
          },
        ],
      }),
    ]);

    const link = wrapper.get('[data-test="playground-cards"] a');
    expect(wrapper.get('[data-test="playground-cards"]').text()).toContain(
      'Spraying Drone'
    );
    expect(link.attributes('href')).toBe(
      'https://shop.example.com/products/drone'
    );
    expect(link.attributes('target')).toBe('_blank');
  });

  it('shows the thank-you note after a form is submitted and calls no API', async () => {
    const wrapper = mountList([
      assistantTurn({
        messages: [
          {
            content: 'Please share your contact details',
            content_type: 'form',
            content_attributes: {
              button_label: 'Submit',
              items: [
                { name: 'name', label: 'Name', type: 'text', required: true },
                {
                  name: 'email',
                  label: 'Email',
                  type: 'email',
                  required: true,
                },
              ],
            },
          },
        ],
        handoff: { source: 'tool', reason: null },
      }),
    ]);
    global.axios = { post: vi.fn(), get: vi.fn() };

    await wrapper.get('input[name="name"]').setValue('Ada');
    await wrapper.get('input[name="email"]').setValue('ada@example.com');
    await wrapper.get('form').trigger('submit');

    expect(wrapper.find('form').exists()).toBe(false);
    expect(wrapper.get('[data-test="form-thanks"]').exists()).toBe(true);
    expect(global.axios.post).not.toHaveBeenCalled();
    delete global.axios;
  });

  it('shows the handoff notice under a reply that handed off', () => {
    const wrapper = mountList([
      assistantTurn({ handoff: { source: 'safety_net', reason: null } }),
    ]);

    expect(wrapper.find('[data-test="playground-handoff"]').exists()).toBe(
      true
    );
  });

  it('draws customer bubbles in the widget colour', () => {
    const wrapper = mountList([userTurn], { widgetColor: '#336699' });

    expect(
      wrapper.get('[class*="rounded-t-xl"]').attributes('style')
    ).toContain('background-color: rgb(51, 102, 153)');
  });
});

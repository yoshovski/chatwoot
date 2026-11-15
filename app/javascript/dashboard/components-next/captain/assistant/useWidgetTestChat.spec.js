import { flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import CaptainAssistant from 'dashboard/api/captain/assistant';
import { useWidgetTestChat } from './useWidgetTestChat';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/api/captain/assistant', () => ({
  default: { playground: vi.fn() },
}));

const reply = {
  response: 'You can follow your order with the tracking link.',
  messages: [
    {
      content: 'You can follow your order with the tracking link.',
      content_type: 'input_select',
      content_attributes: {
        items: [{ title: 'Returns', value: 'How do returns work?' }],
      },
    },
  ],
  sources: [{ kind: 'faq', title: 'Delivery and tracking' }],
  run_details: {
    handler: { title: 'Order status' },
    events: [],
    duration_ms: 2100,
  },
  handoff: null,
  agent_name: 'Order status',
};

const setup = () =>
  useWidgetTestChat({ assistantId: ref(4), agentName: ref('Mila') });

describe('useWidgetTestChat', () => {
  beforeEach(() => {
    CaptainAssistant.playground.mockReset();
    CaptainAssistant.playground.mockResolvedValue({ data: reply });
  });

  it('shows the question, asks the playground and shows the reply bubbles from the AI agent', async () => {
    const chat = setup();

    chat.send('Where is my order?');
    expect(chat.isLoading.value).toBe(true);
    expect(chat.widgetMessages.value).toEqual([
      expect.objectContaining({
        content: 'Where is my order?',
        message_type: 0,
      }),
    ]);
    await flushPromises();

    expect(CaptainAssistant.playground).toHaveBeenCalledWith({
      assistantId: 4,
      messageContent: 'Where is my order?',
      messageHistory: [],
      playgroundConfig: undefined,
    });
    expect(chat.isLoading.value).toBe(false);
    expect(chat.widgetMessages.value[1]).toMatchObject({
      content_type: 'input_select',
      message_type: 1,
      sender: { type: 'captain_assistant', name: 'Mila' },
    });
    expect(chat.replies.value).toEqual([
      expect.objectContaining({
        question: 'Where is my order?',
        answer: reply.response,
        sources: reply.sources,
        runDetails: reply.run_details,
        messageIds: [chat.widgetMessages.value[1].id],
      }),
    ]);
  });

  it('sends the earlier turns with the next question', async () => {
    const chat = setup();
    chat.send('Where is my order?');
    await flushPromises();

    chat.send('Thanks');
    await flushPromises();

    expect(CaptainAssistant.playground).toHaveBeenLastCalledWith(
      expect.objectContaining({
        messageContent: 'Thanks',
        messageHistory: [
          { role: 'user', content: 'Where is my order?' },
          {
            role: 'assistant',
            content: reply.response,
            agent_name: 'Order status',
          },
        ],
      })
    );
  });

  it('keeps a clicked suggestion on its message and asks it as the next question', async () => {
    const chat = setup();
    chat.send('Where is my order?');
    await flushPromises();
    const suggestionMessage = chat.widgetMessages.value[1];
    const submittedValues = [
      { title: 'Returns', value: 'How do returns work?' },
    ];

    chat.submit({ messageId: suggestionMessage.id, submittedValues });

    expect(
      chat.widgetMessages.value[1].content_attributes.submitted_values
    ).toEqual(submittedValues);
    expect(chat.widgetMessages.value.at(-1)).toMatchObject({
      content: 'How do returns work?',
      message_type: 0,
    });
  });

  it('shows an apology in the chat and the reason in the panel when the run fails', async () => {
    CaptainAssistant.playground.mockRejectedValue({
      response: { data: { error: 'model unavailable' } },
    });
    const chat = setup();

    chat.send('Hello');
    await flushPromises();

    expect(chat.widgetMessages.value.at(-1)).toMatchObject({
      content: 'CAPTAIN.PLAYGROUND.WIDGET_TEST.REPLY_FAILED',
      message_type: 1,
    });
    expect(chat.replies.value[0].error).toBe('model unavailable');
  });

  it('drops a reply that arrives after start over', async () => {
    let resolve;
    CaptainAssistant.playground.mockReturnValue(
      new Promise(done => {
        resolve = done;
      })
    );
    const chat = setup();

    chat.send('Hello');
    chat.reset();
    resolve({ data: reply });
    await flushPromises();

    expect(chat.widgetMessages.value).toEqual([]);
    expect(chat.replies.value).toEqual([]);
    expect(chat.isLoading.value).toBe(false);
  });
});

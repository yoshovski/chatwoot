import { computed, ref, unref } from 'vue';
import { useI18n } from 'vue-i18n';
import CaptainAssistant from 'dashboard/api/captain/assistant';

// Widget message types (widget/helpers/constants): the visitor's messages are incoming, the AI agent's outgoing.
const INCOMING = 0;
const OUTGOING = 1;

const nowInSeconds = () => Math.floor(Date.now() / 1000);

// One test conversation in the real widget. The widget shows `widgetMessages`; every AI agent reply also keeps
// what explains it (`replies`). Runs use the playground endpoint, which creates no contact, conversation or usage.
export function useWidgetTestChat({ assistantId, agentName, session = null }) {
  const { t } = useI18n();

  const widgetMessages = ref([]);
  const replies = ref([]);
  const isLoading = ref(false);
  let history = [];
  let nextId = 1;
  let conversationVersion = 0;

  const sender = () => ({
    type: 'captain_assistant',
    name: unref(agentName),
    available_name: unref(agentName),
  });

  const pushMessage = (payload, messageType) => {
    const message = {
      content_type: 'text',
      content_attributes: {},
      ...payload,
      id: nextId,
      message_type: messageType,
      created_at: nowInSeconds(),
      ...(messageType === OUTGOING ? { sender: sender() } : {}),
    };
    nextId += 1;
    widgetMessages.value = [...widgetMessages.value, message];
    return message;
  };

  const send = async content => {
    const text = content?.trim();
    if (!text || isLoading.value) return;

    const question = pushMessage({ content: text }, INCOMING);
    const requestVersion = conversationVersion;
    const messageHistory = history;
    history = [...history, { role: 'user', content: text }];
    isLoading.value = true;

    try {
      const { data } = await CaptainAssistant.playground({
        assistantId: unref(assistantId),
        messageContent: text,
        messageHistory,
        playgroundConfig: session?.hasOverrides
          ? session.playgroundConfig
          : undefined,
      });
      if (requestVersion !== conversationVersion) return;
      if (data.error) throw new Error(data.error);

      const parts = data.messages?.length
        ? data.messages
        : [{ content: data.response }];
      const shown = parts.map(part => pushMessage(part, OUTGOING));
      history = [
        ...history,
        {
          role: 'assistant',
          content: data.response,
          ...(data.agent_name ? { agent_name: data.agent_name } : {}),
        },
      ];
      replies.value = [
        ...replies.value,
        {
          id: question.id,
          question: text,
          answer: data.response,
          messageIds: shown.map(message => message.id),
          // What the reply used, whether or not the bubble shows a Sources card ("Show sources" setting).
          sources: data.sources || [],
          runDetails: data.run_details || null,
          handoff: data.handoff || null,
        },
      ];
    } catch (error) {
      if (requestVersion !== conversationVersion) return;
      const message = pushMessage(
        { content: t('CAPTAIN.PLAYGROUND.WIDGET_TEST.REPLY_FAILED') },
        OUTGOING
      );
      replies.value = [
        ...replies.value,
        {
          id: question.id,
          question: text,
          messageIds: [message.id],
          error:
            error?.response?.data?.error ||
            error?.message ||
            t('CAPTAIN.PLAYGROUND.RESPONSE_ERROR'),
        },
      ];
    } finally {
      if (requestVersion === conversationVersion) isLoading.value = false;
    }
  };

  // A suggestion click or a form answer on an earlier message. The widget draws the answer from the message's
  // submitted values, so they are kept here too; a suggestion is also the visitor's next message.
  const submit = ({ messageId, submittedValues = [], email }) => {
    const message = widgetMessages.value.find(({ id }) => id === messageId);
    if (!message) return;

    widgetMessages.value = widgetMessages.value.map(item =>
      item.id === messageId
        ? {
            ...item,
            content_attributes: {
              ...item.content_attributes,
              submitted_email: email,
              submitted_values: email ? null : submittedValues,
            },
          }
        : item
    );
    if (message.content_type !== 'input_select') return;

    const [option = {}] = submittedValues;
    send(option.value || option.title);
  };

  const reset = () => {
    conversationVersion += 1;
    widgetMessages.value = [];
    replies.value = [];
    history = [];
    isLoading.value = false;
  };

  const replyFor = messageId =>
    replies.value.find(reply => reply.messageIds.includes(messageId));

  return {
    widgetMessages,
    replies,
    isLoading,
    hasConversation: computed(() => widgetMessages.value.length > 0),
    send,
    submit,
    reset,
    replyFor,
  };
}

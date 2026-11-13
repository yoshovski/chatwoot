import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import CaptainAssistant from 'dashboard/api/captain/assistant';

// The test chat of the guided setup: questions go to the AI agent's playground, so nothing reaches a customer.
export function useSetupChat(assistantId) {
  const { t } = useI18n();
  const messages = ref([]);
  const isSending = ref(false);

  const history = () =>
    messages.value
      .filter(message => !message.isError)
      .map(message => ({
        role: message.from === 'user' ? 'user' : 'assistant',
        content: message.text,
      }));

  const ask = async text => {
    if (!assistantId.value || isSending.value) return;
    const messageHistory = history();
    messages.value.push({ from: 'user', text });
    isSending.value = true;
    try {
      const { data } = await CaptainAssistant.playground({
        assistantId: assistantId.value,
        messageContent: text,
        messageHistory,
      });
      messages.value.push(
        data.error
          ? { from: 'agent', text: t('HOME.GUIDED.CHAT.ERROR'), isError: true }
          : { from: 'agent', text: data.response }
      );
    } catch {
      messages.value.push({
        from: 'agent',
        text: t('HOME.GUIDED.CHAT.ERROR'),
        isError: true,
      });
    } finally {
      isSending.value = false;
    }
  };

  return { messages, isSending, ask };
}

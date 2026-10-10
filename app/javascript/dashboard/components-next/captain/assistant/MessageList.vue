<script setup>
import { useI18n } from 'vue-i18n';
import { ref, watch, nextTick } from 'vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import PlaygroundHandoffNotice from './PlaygroundHandoffNotice.vue';
import PlaygroundReply from './PlaygroundReply.vue';
import { accentAttrs } from './playgroundAccent';

const props = defineProps({
  messages: {
    type: Array,
    required: true,
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
  widgetColor: {
    type: String,
    default: '',
  },
  widgetTextColor: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['selectOption']);

const messageContainer = ref(null);

const { t } = useI18n();
const { formatMessage } = useMessageFormatter();

const isUserMessage = sender => sender === 'user';

const getMessageAlignment = sender =>
  isUserMessage(sender) ? 'justify-end' : 'justify-start';

const getMessageDirection = sender =>
  isUserMessage(sender) ? 'flex-row-reverse' : 'flex-row';

const getAvatarName = sender =>
  isUserMessage(sender)
    ? t('CAPTAIN.PLAYGROUND.USER')
    : t('CAPTAIN.PLAYGROUND.ASSISTANT');

const isCustomerView = message =>
  !isUserMessage(message.sender) && !message.isError;

const messageStyle = message => {
  if (message.isError) {
    return 'bg-n-ruby-3 text-n-ruby-11 rounded-es-sm rounded-ee-xl rounded-t-xl';
  }

  return 'rounded-ee-sm rounded-es-xl rounded-t-xl';
};

const scrollToBottom = async () => {
  await nextTick();
  if (messageContainer.value) {
    messageContainer.value.scrollTop = messageContainer.value.scrollHeight;
  }
};

watch(() => props.messages.length, scrollToBottom);
</script>

<template>
  <div
    ref="messageContainer"
    class="flex-1 overflow-y-auto mb-4 px-6 space-y-6"
  >
    <template v-for="(message, index) in messages" :key="index">
      <div class="flex" :class="getMessageAlignment(message.sender)">
        <div
          class="flex max-w-[90%] items-end gap-1.5 md:max-w-[75%]"
          :class="getMessageDirection(message.sender)"
        >
          <Avatar
            :name="getAvatarName(message.sender)"
            rounded-full
            :size="24"
            class="shrink-0"
          />
          <PlaygroundReply
            v-if="isCustomerView(message)"
            :message="message"
            :widget-color="widgetColor"
            :widget-text-color="widgetTextColor"
            :is-latest="index === messages.length - 1"
            @select-option="emit('selectOption', { index, option: $event })"
          />
          <div
            v-else
            class="px-4 py-3 text-sm [overflow-wrap:break-word]"
            :class="messageStyle(message)"
            v-bind="
              message.isError ? {} : accentAttrs(widgetColor, widgetTextColor)
            "
          >
            <div v-dompurify-html="formatMessage(message.content)" />
          </div>
        </div>
      </div>
      <PlaygroundHandoffNotice
        v-if="message.handoff"
        :handoff="message.handoff"
      />
    </template>
    <div v-if="isLoading" class="flex justify-start">
      <div class="flex items-start gap-1.5">
        <Avatar :name="getAvatarName('assistant')" rounded-full :size="24" />
        <div
          class="max-w-sm rounded-lg p-3 text-sm bg-n-slate-3 text-n-slate-12"
        >
          <div class="flex gap-1">
            <div class="w-2 h-2 rounded-full bg-n-slate-10 animate-bounce" />
            <div
              class="w-2 h-2 rounded-full bg-n-slate-10 animate-bounce [animation-delay:0.2s]"
            />
            <div
              class="w-2 h-2 rounded-full bg-n-slate-10 animate-bounce [animation-delay:0.4s]"
            />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

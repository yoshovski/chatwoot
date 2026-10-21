<script setup>
import { computed, reactive, ref, toRef, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { breakpointsTailwind, useBreakpoints } from '@vueuse/core';
import NextButton from 'dashboard/components-next/button/Button.vue';
import SidePanel from 'dashboard/components-next/side-panel/SidePanel.vue';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { useFunctionGetter } from 'dashboard/composables/store.js';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import MessageList from './MessageList.vue';
import PlaygroundInboxPicker from './PlaygroundInboxPicker.vue';
import PlaygroundWidgetBar from './PlaygroundWidgetBar.vue';
import PlaygroundTestSetup from './PlaygroundTestSetup.vue';
import { usePlaygroundSession } from './usePlaygroundSession';
import { useBusinessExamples } from './useBusinessExamples';
import CaptainAssistant from 'dashboard/api/captain/assistant';

const props = defineProps({
  assistantId: {
    type: Number,
    required: true,
  },
});

const { t } = useI18n();
const { isFeatureFlagEnabled } = usePolicy();
const isV2 = computed(() => isFeatureFlagEnabled(FEATURE_FLAGS.CAPTAIN_V2));
const isBelowXL = useBreakpoints(breakpointsTailwind).smaller('xl');

const messages = ref([]);
const newMessage = ref('');
const isLoading = ref(false);
const isSetupOpen = ref(false);
const selectedInbox = ref(null);
const setupPanelRef = ref(null);
const setupInstanceKey = ref(0);
let conversationVersion = 0;

const assistantIdRef = toRef(props, 'assistantId');
const assistant = useFunctionGetter(
  'captainAssistants/getRecord',
  assistantIdRef
);
const { starterQuestions } = useBusinessExamples(assistantIdRef);
const isEmpty = computed(() => !messages.value.length && !isLoading.value);

const session = reactive(
  usePlaygroundSession({
    assistantId: assistantIdRef,
  })
);

const isSendDisabled = computed(
  () =>
    !newMessage.value.trim() ||
    isLoading.value ||
    (isV2.value && (session.isInitializing || Boolean(session.loadError)))
);

const formatMessagesForApi = () => {
  return messages.value
    .filter(message => !message.isError)
    .map(message => {
      const payload = {
        role: message.sender,
        content: message.content,
      };

      if (message.sender === 'assistant' && message.agentName) {
        payload.agent_name = message.agentName;
      }

      return payload;
    });
};

const pushAssistantError = content => {
  messages.value.push({
    content,
    sender: 'assistant',
    isError: true,
    timestamp: new Date().toISOString(),
  });
};

const resetConversation = () => {
  conversationVersion += 1;
  messages.value = [];
  newMessage.value = '';
};

const resetTestSetup = async () => {
  resetConversation();
  setupInstanceKey.value += 1;
  await session.reset();
};

const toggleSetup = () => {
  if (isBelowXL.value) {
    setupPanelRef.value?.open();
  } else {
    isSetupOpen.value = !isSetupOpen.value;
  }
};

watch(
  () => props.assistantId,
  (newId, oldId) => {
    if (oldId && newId !== oldId) {
      resetConversation();
      setupInstanceKey.value += 1;
      if (isV2.value) session.reset();
    }
  }
);

watch(
  isV2,
  enabled => {
    if (enabled) session.initialize();
  },
  { immediate: true }
);

const sendMessage = async (text = newMessage.value) => {
  if (
    !text.trim() ||
    isLoading.value ||
    (isV2.value && session.isInitializing)
  ) {
    return;
  }
  if (isV2.value && session.loadError) {
    pushAssistantError(session.loadError);
    return;
  }
  if (isV2.value && !session.isValid) {
    pushAssistantError(t('CAPTAIN.PLAYGROUND.SETUP.INVALID_CONFIGURATION'));
    return;
  }

  const userMessage = {
    content: text,
    sender: 'user',
    timestamp: new Date().toISOString(),
  };
  messages.value.push(userMessage);
  const currentMessage = text;
  const requestVersion = conversationVersion;
  const setupSummary = isV2.value ? session.configurationSummary() : undefined;
  if (text === newMessage.value) newMessage.value = '';

  try {
    isLoading.value = true;
    const { data } = await CaptainAssistant.playground({
      assistantId: props.assistantId,
      messageContent: currentMessage,
      messageHistory: formatMessagesForApi(),
      playgroundConfig:
        isV2.value && session.hasOverrides
          ? session.playgroundConfig
          : undefined,
    });
    if (requestVersion !== conversationVersion) return;

    messages.value.push({
      content: data.error
        ? t('CAPTAIN.PLAYGROUND.RESPONSE_ERROR')
        : data.response,
      sender: 'assistant',
      agentName: data.agent_name,
      runDetails: data.run_details,
      messages: data.messages,
      handoff: data.handoff,
      setupSummary,
      isError: Boolean(data.error),
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    if (requestVersion !== conversationVersion) return;

    pushAssistantError(
      error?.response?.data?.error ||
        error?.response?.data?.message ||
        t('CAPTAIN.PLAYGROUND.RESPONSE_ERROR')
    );
  } finally {
    isLoading.value = false;
  }
};

// A suggestion button sends its value (the full question) as the customer's next message, like in the widget.
const selectOption = ({ index, option }) => {
  if (isLoading.value) return;

  messages.value[index].selectedOption = option.title;
  sendMessage(option.value || option.title);
};

const handleEnterKey = event => {
  if (event.isComposing) return;
  event.preventDefault();
  sendMessage();
};
</script>

<template>
  <div
    class="flex h-full overflow-hidden rounded-xl border border-n-weak text-n-slate-11"
  >
    <div class="flex flex-col flex-1 min-w-0">
      <header
        class="flex items-center justify-between gap-3 px-4 py-2.5 border-b border-n-weak"
      >
        <PlaygroundWidgetBar
          v-if="isV2"
          :assistant-id="assistantId"
          :widget-color="selectedInbox?.widget_color"
          :widget-text-color="selectedInbox?.widget_text_color"
          class="min-w-0"
        />
        <h3 v-else class="m-0 text-sm font-medium text-n-slate-12">
          {{ t('CAPTAIN.PLAYGROUND.HEADER') }}
        </h3>
        <div class="flex items-center gap-1 shrink-0">
          <PlaygroundInboxPicker
            v-if="isV2"
            v-model="selectedInbox"
            :assistant-id="assistantId"
          />
          <NextButton
            v-tooltip.bottom="t('CAPTAIN.PLAYGROUND.CLEAR_CONVERSATION')"
            ghost
            sm
            slate
            icon="i-lucide-rotate-ccw"
            :aria-label="t('CAPTAIN.PLAYGROUND.CLEAR_CONVERSATION')"
            @click="resetConversation"
          />
          <NextButton
            v-if="isV2"
            v-tooltip.bottom="t('CAPTAIN.PLAYGROUND.SETUP.TOGGLE')"
            ghost
            sm
            :slate="!isSetupOpen"
            icon="i-lucide-settings-2"
            :aria-label="t('CAPTAIN.PLAYGROUND.SETUP.TOGGLE')"
            :aria-pressed="isSetupOpen"
            @click="toggleSetup"
          />
        </div>
      </header>

      <div
        class="flex flex-col flex-1 w-full max-w-3xl min-h-0 gap-3 pt-4 pb-3 mx-auto"
      >
        <div
          v-if="isEmpty"
          class="flex flex-col items-center justify-center flex-1 gap-4 px-6 text-center"
        >
          <Avatar
            :name="assistant.name || ''"
            :src="assistant.avatar_url"
            :size="48"
            icon-name="i-lucide-bot-message-square"
            rounded-full
          />
          <div class="flex flex-col gap-1">
            <h4 class="m-0 text-base font-medium text-n-slate-12">
              {{
                t('CAPTAIN.PLAYGROUND.EMPTY.TITLE', { name: assistant.name })
              }}
            </h4>
            <p class="m-0 text-sm text-n-slate-11">
              {{ t('CAPTAIN.PLAYGROUND.EMPTY.DESCRIPTION') }}
            </p>
          </div>
          <div class="flex flex-wrap justify-center gap-2 max-w-xl">
            <button
              v-for="question in starterQuestions"
              :key="question"
              type="button"
              class="px-3 py-1.5 text-sm text-start rounded-full bg-n-solid-1 outline outline-1 outline-n-weak text-n-slate-12 transition-colors hover:outline-n-strong hover:bg-n-alpha-1"
              @click="sendMessage(question)"
            >
              {{ question }}
            </button>
          </div>
        </div>
        <MessageList
          v-show="!isEmpty"
          :messages="messages"
          :is-loading="isLoading"
          :widget-color="selectedInbox?.widget_color"
          :widget-text-color="selectedInbox?.widget_text_color"
          @select-option="selectOption"
        />

        <div class="px-4 sm:px-6">
          <div
            class="flex items-center gap-2 py-2 ps-4 pe-2 rounded-2xl bg-n-solid-1 outline outline-1 outline-n-weak shadow-sm transition-[outline-color] focus-within:outline-n-brand"
          >
            <input
              v-model="newMessage"
              class="flex-1 mb-0 text-sm bg-transparent border-none text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none"
              :placeholder="t('CAPTAIN.PLAYGROUND.MESSAGE_PLACEHOLDER')"
              @keydown.enter.exact="handleEnterKey"
            />
            <NextButton
              sm
              :disabled="isSendDisabled"
              icon="i-lucide-send"
              class="!rounded-full"
              :aria-label="t('CAPTAIN.PLAYGROUND.SEND_MESSAGE')"
              @click="sendMessage()"
            />
          </div>
          <p class="m-0 pt-2 text-xs text-center text-n-slate-10">
            {{ t('CAPTAIN.PLAYGROUND.CREDIT_NOTE') }}
          </p>
        </div>
      </div>
    </div>

    <aside
      v-if="isV2 && isSetupOpen && !isBelowXL"
      aria-labelledby="playground-test-setup-title"
      class="flex w-[24rem] flex-none flex-col border-s border-n-weak bg-n-surface-1 text-n-slate-12"
    >
      <div
        class="flex items-center justify-between gap-3 px-4 py-2.5 border-b border-n-weak"
      >
        <h3 id="playground-test-setup-title" class="m-0 text-sm font-medium">
          {{ t('CAPTAIN.PLAYGROUND.SETUP.TITLE') }}
        </h3>
        <NextButton
          ghost
          sm
          slate
          icon="i-lucide-x"
          :aria-label="t('CAPTAIN.PLAYGROUND.SETUP.CLOSE')"
          @click="isSetupOpen = false"
        />
      </div>
      <PlaygroundTestSetup
        :key="setupInstanceKey"
        :session="session"
        class="flex-1 min-h-0"
      />
      <div class="p-3 border-t border-n-weak bg-n-solid-1">
        <NextButton
          ghost
          sm
          slate
          :label="t('CAPTAIN.PLAYGROUND.SETUP.RESET')"
          icon="i-lucide-refresh-cw"
          :disabled="session.isInitializing"
          :is-loading="session.isInitializing"
          @click="resetTestSetup"
        />
      </div>
    </aside>

    <SidePanel
      v-if="isV2 && isBelowXL"
      ref="setupPanelRef"
      width="lg"
      :title="t('CAPTAIN.PLAYGROUND.SETUP.TITLE')"
      :description="t('CAPTAIN.PLAYGROUND.SETUP.DESCRIPTION')"
    >
      <PlaygroundTestSetup :key="setupInstanceKey" :session="session" />
      <template #footer>
        <NextButton
          ghost
          sm
          slate
          :label="t('CAPTAIN.PLAYGROUND.SETUP.RESET')"
          icon="i-lucide-refresh-cw"
          :disabled="session.isInitializing"
          :is-loading="session.isInitializing"
          @click="resetTestSetup"
        />
      </template>
    </SidePanel>
  </div>
</template>

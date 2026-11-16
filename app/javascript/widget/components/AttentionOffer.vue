<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { emitter } from 'shared/helpers/mitt';
import { ON_UNREAD_MESSAGE_CLICK } from 'widget/constants/widgetBusEvents';
import { attentionState } from 'widget/helpers/attentionState';
import {
  clearAttentionOffer,
  dismissAttention,
} from 'widget/composables/useWidgetAttention';
import PreviewChoices from './PreviewChoices.vue';
import ChatOption from 'shared/components/ChatOption.vue';

// The "anything else?" check-in. It is shown, not posted, so it never emails the visitor,
// restarts the conversation clock or counts as an AI reply. The assistant writes the line and the
// next-step choices for this conversation; the fixed line and the reply's own buttons are the fallback.
defineProps({
  // card: inside the closed-chat card. chat: an agent bubble at the end of the open conversation.
  variant: { type: String, default: 'chat' },
});

const store = useStore();
const router = useRouter();
const { t } = useI18n();
const sending = ref(false);
const text = computed(
  () => attentionState.offer?.text || t('ATTENTION.CHECK_IN')
);
const suggestions = computed(() => attentionState.offer?.suggestions || []);

const choose = async choice => {
  if (sending.value) return;
  sending.value = true;
  clearAttentionOffer();
  if (router.currentRoute.value.name !== 'messages') {
    emitter.emit(ON_UNREAD_MESSAGE_CLICK);
    await router.replace({ name: 'messages' });
  }
  await store.dispatch('conversation/sendMessage', {
    content: choice.value || choice.title,
  });
  sending.value = false;
};
</script>

<template>
  <div
    v-if="variant === 'card'"
    role="status"
    aria-live="polite"
    data-testid="attention-offer"
  >
    <p class="m-0 px-5 pb-4 pt-1 text-[0.9375rem] leading-6 text-n-slate-12">
      {{ text }}
    </p>
    <PreviewChoices :choices="suggestions" :disabled="sending" @choose="choose">
      <button
        type="button"
        class="flex w-full items-center rounded-xl px-3 py-2.5 text-start text-[0.9375rem] text-n-slate-11 hover:bg-n-alpha-1"
        @click="dismissAttention"
      >
        {{ $t('ATTENTION.ALL_SET') }}
      </button>
    </PreviewChoices>
  </div>
  <!-- In the open chat: a message from the assistant, then its choices and the way out. -->
  <div
    v-else
    class="mt-3 flex animate-fade-in-up flex-col items-start gap-2 pe-4 ps-10"
    role="status"
    aria-live="polite"
    data-testid="attention-offer"
  >
    <div
      class="chat-bubble agent bg-n-slate-3 text-n-slate-12 dark:bg-n-solid-3"
    >
      {{ text }}
    </div>
    <ul class="m-0 flex list-none flex-wrap gap-2 p-0">
      <ChatOption
        v-for="choice in suggestions"
        :key="choice.id || choice.value || choice.title"
        :action="choice"
        :disabled="sending"
        @option-select="choose"
      />
      <ChatOption
        :action="{ title: $t('ATTENTION.ALL_SET'), kind: 'follow_up' }"
        :disabled="sending"
        @option-select="dismissAttention"
      />
    </ul>
  </div>
</template>

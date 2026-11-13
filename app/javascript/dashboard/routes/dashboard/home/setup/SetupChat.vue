<script setup>
// The chat widget as a customer sees it (same look as the sign-up panel's WidgetPreview), used to talk to the new AI
// agent during setup. Messages are { from: 'user' | 'agent', text, isError }.
import { nextTick, ref, watch } from 'vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  messages: { type: Array, default: () => [] },
  isSending: { type: Boolean, default: false },
});

const emit = defineEmits(['ask']);

const draft = ref('');
const list = ref(null);

const send = () => {
  const text = draft.value.trim();
  if (!text || props.isSending) return;
  emit('ask', text);
  draft.value = '';
};

watch(
  () => [props.messages.length, props.isSending],
  async () => {
    await nextTick();
    list.value?.scrollTo({ top: list.value.scrollHeight });
  }
);
</script>

<template>
  <div
    class="flex w-full flex-col overflow-hidden rounded-2xl bg-white font-sans shadow-[0_5px_40px_rgba(0,0,0,0.16)]"
  >
    <div class="flex items-center gap-3 bg-[#fafafa] px-4 py-3">
      <span
        class="flex size-8 shrink-0 items-center justify-center rounded-full bg-[#1f93ff] text-white"
      >
        <Icon icon="i-lucide-bot" class="size-4" />
      </span>
      <div class="min-w-0">
        <p class="mb-0 truncate text-base text-[#1c2024]">
          {{ $t('HOME.GUIDED.CHAT.SHOP') }}
        </p>
        <p class="mb-0 text-xs text-[#60646c]">
          {{ $t('HOME.GUIDED.CHAT.REPLY_TIME') }}
        </p>
      </div>
    </div>
    <div
      ref="list"
      class="flex h-[22rem] flex-col gap-3 overflow-y-auto px-4 pt-4 pb-3"
      aria-live="polite"
    >
      <p
        v-if="!messages.length && !isSending"
        class="m-auto max-w-[16rem] text-center text-sm text-[#60646c]"
      >
        {{ $t('HOME.GUIDED.CHAT.EMPTY') }}
      </p>
      <template v-for="(message, index) in messages" :key="index">
        <p
          v-if="message.from === 'user'"
          class="mb-0 max-w-[78%] self-end whitespace-pre-line rounded-[1.25rem] rounded-br-[0.25rem] bg-[#1f93ff] px-4 py-3 text-sm leading-normal text-white"
        >
          {{ message.text }}
        </p>
        <div v-else class="flex items-end gap-2">
          <span
            class="flex size-6 shrink-0 items-center justify-center rounded-full bg-[#1f93ff] text-white"
          >
            <Icon icon="i-lucide-bot" class="size-3.5" />
          </span>
          <p
            class="mb-0 max-w-[18rem] whitespace-pre-line rounded-[1.25rem] rounded-bl-[0.25rem] px-4 py-3 text-sm leading-normal"
            :class="
              message.isError
                ? 'bg-[#fff0ef] text-[#ce2c31]'
                : 'bg-[#f0f0f3] text-[#1c2024]'
            "
          >
            {{ message.text }}
          </p>
        </div>
      </template>
      <div v-if="isSending" class="flex items-end gap-2">
        <span
          class="flex size-6 shrink-0 items-center justify-center rounded-full bg-[#1f93ff] text-white"
        >
          <Icon icon="i-lucide-bot" class="size-3.5" />
        </span>
        <span
          class="flex gap-1 rounded-[1.25rem] rounded-bl-[0.25rem] bg-[#f0f0f3] px-4 py-4"
        >
          <span
            v-for="dot in 3"
            :key="dot"
            class="size-1.5 animate-pulse rounded-full bg-[#8b8d98]"
          />
        </span>
      </div>
    </div>
    <form
      class="flex items-center gap-3 border-t border-[#e8e8ec] px-4 py-3"
      @submit.prevent="send"
    >
      <input
        v-model="draft"
        type="text"
        class="!mb-0 h-8 min-w-0 flex-1 !rounded-none !border-none !bg-transparent !p-0 text-sm !text-[#1c2024] !shadow-none !outline-none placeholder:text-[#8b8d98]"
        :placeholder="$t('HOME.GUIDED.CHAT.COMPOSER')"
        :aria-label="$t('HOME.GUIDED.CHAT.COMPOSER')"
      />
      <button
        type="submit"
        class="flex size-8 shrink-0 items-center justify-center rounded-full bg-[#f0f0f3] text-[#60646c] disabled:opacity-50"
        :disabled="!draft.trim() || isSending"
        :aria-label="$t('HOME.GUIDED.CHAT.SEND')"
      >
        <Icon icon="i-lucide-send-horizontal" class="size-4" />
      </button>
    </form>
  </div>
</template>

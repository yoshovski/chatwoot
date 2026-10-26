<script setup>
import { ref } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import CaptainConversationsAPI from 'dashboard/api/captain/conversations';

import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  conversationId: { type: Number, required: true },
  assistantName: { type: String, required: true },
});

const emit = defineEmits(['takenOver', 'addNote']);

const store = useStore();
const { t } = useI18n();

const isTakingOver = ref(false);

// Taking over opens the conversation, assigns it to the agent and stops
// Captain from answering, in one request.
const takeOver = async () => {
  if (isTakingOver.value) return;
  isTakingOver.value = true;
  try {
    await CaptainConversationsAPI.takeOver(props.conversationId);
    await store.dispatch('getConversation', props.conversationId);
    useAlert(t('CONVERSATION.BOT_HANDOFF_SUCCESS'));
    emit('takenOver');
  } catch (error) {
    useAlert(t('CONVERSATION.BOT_HANDOFF_ERROR'));
  } finally {
    isTakingOver.value = false;
  }
};

useKeyboardEvents({
  Enter: e => {
    e.preventDefault();
    takeOver();
  },
});
</script>

<template>
  <div
    class="absolute inset-0 z-20 flex flex-col items-center justify-center gap-3 px-4 rounded-xl bg-n-solid-1/85 backdrop-blur-[2px]"
  >
    <p class="mb-0 text-sm text-center text-n-slate-11">
      {{ $t('CONVERSATION.CAPTAIN_GATE.MESSAGE', { assistantName }) }}
    </p>
    <div class="flex flex-wrap items-center justify-center gap-2">
      <Button
        :label="$t('CONVERSATION.BOT_HANDOFF_ACTION')"
        :is-loading="isTakingOver"
        @click="takeOver"
      />
      <Button
        :label="$t('CONVERSATION.CAPTAIN_GATE.ADD_NOTE')"
        variant="outline"
        color="slate"
        :disabled="isTakingOver"
        @click="emit('addNote')"
      />
    </div>
    <p class="flex items-center gap-1.5 mb-0 text-xs text-n-slate-11">
      {{ $t('CONVERSATION.CAPTAIN_GATE.OR_PRESS') }}
      <kbd
        class="px-1.5 py-0.5 text-xs font-medium border rounded-md border-n-weak bg-n-alpha-1 text-n-slate-12"
      >
        {{ $t('CONVERSATION.CAPTAIN_GATE.ENTER_KEY') }}
      </kbd>
      {{ $t('CONVERSATION.CAPTAIN_GATE.TO_TAKE_OVER') }}
    </p>
  </div>
</template>

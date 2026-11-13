<script setup>
import { computed } from 'vue';
import {
  CONVERSATION_STATE_META,
  useConversationStateLabel,
} from './conversationState';

// A conversation's state as a pill (thread header).
const props = defineProps({
  state: { type: String, required: true },
});

const stateLabel = useConversationStateLabel();
const meta = computed(() => CONVERSATION_STATE_META[props.state]);
const label = computed(() => stateLabel(props.state));
</script>

<template>
  <span
    class="inline-flex shrink-0 items-center gap-1.5 rounded-full px-2 py-0.5 text-xs font-medium"
    :class="meta.pill"
  >
    <span class="size-1.5 shrink-0 rounded-full" :class="meta.dot" />
    {{ label }}
  </span>
</template>

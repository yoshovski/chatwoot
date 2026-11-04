<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { dynamicTime } from 'shared/helpers/timeHelper';
import CaptainConversationsAPI from 'dashboard/api/captain/conversations';
import Button from 'dashboard/components-next/button/Button.vue';

// Shows the AI agent's pending follow-ups in a conversation, with Cancel. Refreshes when a new message arrives,
// because a visitor message or a human reply cancels them on the server.
const props = defineProps({
  conversationId: { type: [Number, String], required: true },
  lastMessageId: { type: [Number, String], default: null },
});

const { t } = useI18n();
const actions = ref([]);
const cancellingId = ref(null);

const fetchActions = async () => {
  try {
    const { data } = await CaptainConversationsAPI.getScheduledActions(
      props.conversationId
    );
    actions.value = data.payload || [];
  } catch {
    actions.value = [];
  }
};

const cancel = async action => {
  cancellingId.value = action.id;
  try {
    await CaptainConversationsAPI.cancelScheduledAction(
      props.conversationId,
      action.id
    );
    actions.value = actions.value.filter(item => item.id !== action.id);
  } catch {
    useAlert(t('CAPTAIN.SCHEDULED_ACTIONS.CANCEL_ERROR'));
  } finally {
    cancellingId.value = null;
  }
};

const labelFor = action => {
  const time = dynamicTime(action.due_at);
  return action.kind === 'follow_up_email'
    ? t('CAPTAIN.SCHEDULED_ACTIONS.KIND.FOLLOW_UP_EMAIL', { time })
    : t('CAPTAIN.SCHEDULED_ACTIONS.KIND.FOLLOW_UP_MESSAGE', { time });
};

watch(() => [props.conversationId, props.lastMessageId], fetchActions, {
  immediate: true,
});
</script>

<template>
  <div class="flex flex-col gap-1.5 px-4 empty:hidden">
    <div
      v-for="action in actions"
      :key="action.id"
      data-test="scheduled-follow-up"
      class="flex items-center justify-between gap-2 px-2.5 py-1 rounded-lg bg-n-iris-3 text-n-iris-11 border border-n-iris-4"
    >
      <span class="flex items-center gap-1.5 text-xs font-medium truncate">
        <span class="i-lucide-alarm-clock size-3.5 shrink-0" />
        {{ labelFor(action) }}
      </span>
      <Button
        xs
        ghost
        slate
        :label="t('CAPTAIN.SCHEDULED_ACTIONS.CANCEL')"
        :is-loading="cancellingId === action.id"
        @click="cancel(action)"
      />
    </div>
  </div>
</template>

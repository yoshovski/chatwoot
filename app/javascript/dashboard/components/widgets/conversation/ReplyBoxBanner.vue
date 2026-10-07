<script setup>
import { computed } from 'vue';
import { useStore } from 'vuex';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import wootConstants from 'dashboard/constants/globals';
import CaptainConversationsAPI from 'dashboard/api/captain/conversations';

import Banner from 'dashboard/components/ui/Banner.vue';

const props = defineProps({
  message: {
    type: String,
    default: '',
  },
  isOnPrivateNote: {
    type: Boolean,
    default: false,
  },
});

const store = useStore();
const { t } = useI18n();

const currentChat = useMapGetter('getSelectedChat');
const currentUser = useMapGetter('getCurrentUser');

const assignedAgent = computed({
  get() {
    return currentChat.value?.meta?.assignee;
  },
  set(agent) {
    const agentId = agent ? agent.id : null;
    store.dispatch('setCurrentChatAssignee', {
      conversationId: currentChat.value?.id,
      assignee: agent,
      assigneeType: agent ? 'User' : null,
    });
    store.dispatch('assignAgent', {
      conversationId: currentChat.value?.id,
      agentId,
    });
  },
});

const hasMessage = computed(() => props.message !== '');
const isUserTyping = computed(() => hasMessage.value && !props.isOnPrivateNote);
const isUnassigned = computed(() => !assignedAgent.value);
const isAssignedToOtherAgent = computed(
  () => assignedAgent.value?.id !== currentUser.value?.id
);

const showSelfAssignBanner = computed(() => {
  return (
    isUserTyping.value && (isUnassigned.value || isAssignedToOtherAgent.value)
  );
});

const isPendingConversation = computed(
  () => currentChat.value?.status === wootConstants.STATUS_TYPE.PENDING
);

const isAgentBotOwned = computed(
  () => currentChat.value?.meta?.assignee_type === 'AgentBot'
);

const isCaptainOwned = computed(
  () => currentChat.value?.meta?.assignee_type === 'Captain::Assistant'
);

const showBotHandoffBanner = computed(() => {
  return (
    isPendingConversation.value &&
    (isAgentBotOwned.value || isCaptainOwned.value)
  );
});

// After a handoff, Captain can keep answering an open conversation (even one
// assigned to an agent) until someone takes over.
const captainWaitingAssistant = computed(
  () => currentChat.value?.meta?.captain_waiting
);

const showCaptainWaitingBanner = computed(
  () => !showBotHandoffBanner.value && Boolean(captainWaitingAssistant.value)
);

const botAssigneeName = computed(() => {
  if (
    (isAgentBotOwned.value || isCaptainOwned.value) &&
    assignedAgent.value?.name
  ) {
    return assignedAgent.value.name;
  }

  return t('CONVERSATION.BOT_HANDOFF_FALLBACK_ASSIGNEE');
});

const selfAssignConversation = async () => {
  const { avatar_url, ...rest } = currentUser.value || {};
  assignedAgent.value = { ...rest, thumbnail: avatar_url };
};

const needsAssignmentToCurrentUser = computed(() => {
  return isUnassigned.value || isAssignedToOtherAgent.value;
});

const onClickSelfAssign = async () => {
  try {
    await selfAssignConversation();
    useAlert(t('CONVERSATION.CHANGE_AGENT'));
  } catch (error) {
    useAlert(t('CONVERSATION.CHANGE_AGENT_FAILED'));
  }
};

const reopenConversation = async () => {
  await store.dispatch('toggleStatus', {
    conversationId: currentChat.value?.id,
    status: 'open',
  });
};

// Taking over from Captain opens the conversation, assigns it to the agent and
// stops Captain from answering, in one request.
const takeOverFromCaptain = async () => {
  try {
    await CaptainConversationsAPI.takeOver(currentChat.value?.id);
    await store.dispatch('getConversation', currentChat.value?.id);
    useAlert(t('CONVERSATION.BOT_HANDOFF_SUCCESS'));
  } catch (error) {
    useAlert(t('CONVERSATION.BOT_HANDOFF_ERROR'));
  }
};

const onClickBotHandoff = async () => {
  if (isCaptainOwned.value) {
    await takeOverFromCaptain();
    return;
  }

  try {
    const shouldAssignToCurrentUser =
      isAgentBotOwned.value || needsAssignmentToCurrentUser.value;

    await reopenConversation();

    if (shouldAssignToCurrentUser) {
      await selfAssignConversation();
    }

    useAlert(t('CONVERSATION.BOT_HANDOFF_SUCCESS'));
  } catch (error) {
    useAlert(t('CONVERSATION.BOT_HANDOFF_ERROR'));
  }
};
</script>

<template>
  <Banner
    v-if="
      showSelfAssignBanner && !showBotHandoffBanner && !showCaptainWaitingBanner
    "
    action-button-variant="ghost"
    color-scheme="secondary"
    class="mx-2 mb-2 rounded-lg !py-2"
    :banner-message="$t('CONVERSATION.NOT_ASSIGNED_TO_YOU')"
    has-action-button
    :action-button-label="$t('CONVERSATION.ASSIGN_TO_ME')"
    @primary-action="onClickSelfAssign"
  />
  <Banner
    v-if="showBotHandoffBanner"
    action-button-variant="ghost"
    color-scheme="secondary"
    class="mx-2 mb-2 rounded-lg !py-2"
    :banner-message="
      $t('CONVERSATION.BOT_HANDOFF_MESSAGE', {
        assigneeName: botAssigneeName,
      })
    "
    has-action-button
    :action-button-label="$t('CONVERSATION.BOT_HANDOFF_ACTION')"
    @primary-action="onClickBotHandoff"
  />
  <Banner
    v-if="showCaptainWaitingBanner"
    action-button-variant="ghost"
    color-scheme="secondary"
    class="mx-2 mb-2 rounded-lg !py-2"
    :banner-message="
      $t('CONVERSATION.CAPTAIN_WAITING_MESSAGE', {
        assistantName: captainWaitingAssistant.name,
      })
    "
    has-action-button
    :action-button-label="$t('CONVERSATION.BOT_HANDOFF_ACTION')"
    @primary-action="takeOverFromCaptain"
  />
</template>

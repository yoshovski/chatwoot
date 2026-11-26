<script setup>
import { ref, computed, onMounted, onUnmounted, useAttrs } from 'vue';
import { useI18n } from 'vue-i18n';
import ConversationApi from 'dashboard/api/conversations';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useAlert } from 'dashboard/composables';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { useMapGetter, useStore } from 'dashboard/composables/store.js';
import { getUnixTime } from 'date-fns';
import { findSnoozeTime } from 'dashboard/helper/snoozeHelpers';
import { emitter } from 'shared/helpers/mitt';
import { useBulkActions } from 'dashboard/composables/chatlist/useBulkActions.js';
import wootConstants from 'dashboard/constants/globals';
import {
  CMD_BULK_ACTION_SNOOZE_CONVERSATION,
  CMD_BULK_ACTION_REOPEN_CONVERSATION,
  CMD_BULK_ACTION_RESOLVE_CONVERSATION,
} from 'dashboard/helper/commandbar/events';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import BulkAgentActions from './BulkAgentActions.vue';
import BulkUpdateActions from './BulkUpdateActions.vue';
import BulkLabelActions from './BulkLabelActions.vue';
import BulkTeamActions from './BulkTeamActions.vue';
import CustomSnoozeModal from 'dashboard/components/CustomSnoozeModal.vue';

const props = defineProps({
  loadedCount: { type: Number, default: 0 },
  conversations: {
    type: Array,
    default: () => [],
  },
  allConversationsSelected: {
    type: Boolean,
    default: false,
  },
  selectedInboxes: {
    type: Array,
    default: () => [],
  },
  showOpenAction: {
    type: Boolean,
    default: false,
  },
  showResolvedAction: {
    type: Boolean,
    default: false,
  },
  showSnoozedAction: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['selectAllConversations', 'deleted']);

defineOptions({
  inheritAttrs: false,
});

const attrs = useAttrs();
const { t } = useI18n();

const {
  selectedConversations,
  onAssignAgent,
  onAssignLabels,
  onRemoveLabels,
  onAssignTeamsForBulk: onAssignTeam,
  onUpdateConversations,
} = useBulkActions();

const { isAdmin } = useAdmin();
const store = useStore();
const deleteDialog = ref(null);
const deleteIds = ref([]);
const isDeleting = ref(false);
const deletionAccount = ref(null);

function confirmDelete() {
  if (!isAdmin.value || isDeleting.value) return;
  deletionAccount.value = ConversationApi.accountIdFromRoute;
  deleteIds.value = [...props.conversations];
  deleteDialog.value.open();
}

async function deleteSelected() {
  if (!isAdmin.value || isDeleting.value) return;
  isDeleting.value = true;
  const deleted = [];
  const failed = [];
  await deleteIds.value.reduce(async (previous, id) => {
    await previous;
    if (
      !deletionAccount.value ||
      deletionAccount.value !== ConversationApi.accountIdFromRoute
    ) {
      failed.push(id);
      return;
    }
    try {
      // Each request goes through the existing account and role checks.
      await store.dispatch('deleteConversation', id);
      await store.dispatch('bulkActions/removeSelectedConversationIds', id);
      deleted.push(id);
    } catch {
      failed.push(id);
    }
  }, Promise.resolve());
  isDeleting.value = false;
  deleteDialog.value?.close();
  emit('deleted', deleted);
  if (deleted.length)
    useAlert(t('BULK_ACTION.DELETE_QUEUED', { count: deleted.length }));
  if (failed.length)
    useAlert(
      t('BULK_ACTION.DELETE_FAILED', {
        ids: failed.map(id => '#' + id).join(', '),
      })
    );
}

const getConversationById = useMapGetter('getConversationById');

const appliedLabelsForSelection = computed(() => {
  const applied = new Set();
  selectedConversations.value.forEach(id => {
    const conversation = getConversationById.value(id);
    (conversation?.labels || []).forEach(label => applied.add(label));
  });
  return Array.from(applied);
});

const selectedLabel = computed(() =>
  t('BULK_ACTION.CONVERSATIONS_SELECTED', {
    conversationCount: props.conversations.length,
  })
);

const showCustomTimeSnoozeModal = ref(false);

function onCmdSnoozeConversation(snoozeType) {
  if (snoozeType === wootConstants.SNOOZE_OPTIONS.UNTIL_CUSTOM_TIME) {
    showCustomTimeSnoozeModal.value = true;
  } else if (typeof snoozeType === 'number') {
    onUpdateConversations('snoozed', snoozeType);
  } else {
    onUpdateConversations('snoozed', findSnoozeTime(snoozeType) || null);
  }
}

function onCmdReopenConversation() {
  onUpdateConversations('open', null);
}

function onCmdResolveConversation() {
  onUpdateConversations('resolved', null);
}

function customSnoozeTime(customSnoozedTime) {
  showCustomTimeSnoozeModal.value = false;
  if (customSnoozedTime) {
    onUpdateConversations('snoozed', getUnixTime(customSnoozedTime));
  }
}

function hideCustomSnoozeModal() {
  showCustomTimeSnoozeModal.value = false;
}

// Computed property with getter/setter to enable v-model usage
const allSelected = computed({
  get: () => props.allConversationsSelected,
  set: value => {
    emit('selectAllConversations', value);
  },
});

onMounted(() => {
  emitter.on(CMD_BULK_ACTION_SNOOZE_CONVERSATION, onCmdSnoozeConversation);
  emitter.on(CMD_BULK_ACTION_REOPEN_CONVERSATION, onCmdReopenConversation);
  emitter.on(CMD_BULK_ACTION_RESOLVE_CONVERSATION, onCmdResolveConversation);
});

onUnmounted(() => {
  emitter.off(CMD_BULK_ACTION_SNOOZE_CONVERSATION, onCmdSnoozeConversation);
  emitter.off(CMD_BULK_ACTION_REOPEN_CONVERSATION, onCmdReopenConversation);
  emitter.off(CMD_BULK_ACTION_RESOLVE_CONVERSATION, onCmdResolveConversation);
});
</script>

<template>
  <div
    v-if="conversations.length > 0"
    v-bind="attrs"
    class="relative z-30 w-full shrink-0 border-b border-n-weak bg-n-solid-2"
  >
    <div
      class="flex items-center justify-between gap-2 p-2 queue-selection-heading flex-wrap text-sm !gap-1 !ps-[var(--selection-inset,1.5rem)] pe-2 min-h-[calc(3.25rem-1px)]"
    >
      <div class="flex items-center gap-1 min-w-0">
        <label class="cursor-pointer flex items-center gap-1.5 min-w-0">
          <Checkbox
            v-model="allSelected"
            :aria-label="
              $t('BULK_ACTION.SELECT_LOADED', { count: loadedCount })
            "
            :indeterminate="!allConversationsSelected"
            class="flex-shrink-0"
          />
          <span :title="selectedLabel" class="cursor-pointer truncate">
            {{ selectedLabel }}
          </span>
        </label>
        <NextButton
          v-tooltip="$t('BULK_ACTION.CLEAR_SELECTION')"
          icon="i-lucide-x"
          :aria-label="$t('BULK_ACTION.CLEAR_SELECTION')"
          ghost
          class="!px-1 !h-6 flex-shrink-0 !w-5 !text-n-slate-11"
          sm
          @click="allSelected = false"
        />
      </div>
      <div
        class="flex items-center shrink-0 gap-0 [&>div]:!static [&>div>.absolute]:!top-full [&>div>.absolute]:!bottom-auto [&>div>.absolute]:!start-auto [&>div>.absolute]:!end-2"
      >
        <BulkLabelActions @assign="onAssignLabels" />
        <BulkLabelActions
          action="remove"
          :applied-labels="appliedLabelsForSelection"
          @remove="onRemoveLabels"
        />
        <BulkUpdateActions
          :show-resolve="!showResolvedAction"
          :show-reopen="!showOpenAction"
          :show-snooze="!showSnoozedAction"
          @update="onUpdateConversations"
        />
        <BulkAgentActions
          :selected-inboxes="selectedInboxes"
          :conversation-count="conversations.length"
          @select="onAssignAgent"
        />
        <BulkTeamActions
          :conversation-count="conversations.length"
          @select="onAssignTeam"
        />
        <NextButton
          v-if="isAdmin"
          v-tooltip="$t('CONVERSATION.DELETE_CONVERSATION.CONFIRM')"
          :aria-label="$t('CONVERSATION.DELETE_CONVERSATION.CONFIRM')"
          icon="i-lucide-trash-2"
          size="xs"
          slate
          ghost
          :disabled="isDeleting"
          @click="confirmDelete"
        />
      </div>
    </div>
  </div>
  <Dialog
    v-if="isAdmin"
    ref="deleteDialog"
    type="alert"
    :title="$t('BULK_ACTION.DELETE_COUNT', { count: deleteIds.length })"
    :description="$t('BULK_ACTION.DELETE_DESCRIPTION')"
    :confirm-button-label="$t('CONVERSATION.DELETE_CONVERSATION.CONFIRM')"
    :is-loading="isDeleting"
    @confirm="deleteSelected"
  />
  <woot-modal
    v-model:show="showCustomTimeSnoozeModal"
    :on-close="hideCustomSnoozeModal"
  >
    <CustomSnoozeModal
      @close="hideCustomSnoozeModal"
      @choose-time="customSnoozeTime"
    />
  </woot-modal>
</template>

<script setup>
import { computed, watch, ref, nextTick } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useRoute } from 'vue-router';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useAssistantSettings } from 'dashboard/routes/dashboard/captain/assistants/settings/useAssistantSettings';

import DeleteDialog from 'dashboard/components-next/captain/pageComponents/DeleteDialog.vue';
import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import ConnectInboxPanel from 'dashboard/components-next/captain/pageComponents/inbox/ConnectInboxPanel.vue';
import InboxCard from 'dashboard/components-next/captain/assistant/InboxCard.vue';
import InboxPageEmptyState from 'dashboard/components-next/captain/pageComponents/emptyStates/InboxPageEmptyState.vue';

const store = useStore();
const route = useRoute();
const isConnectPanelOpen = ref(false);

const assistantId = computed(() => Number(route.params.assistantId));
const { assistant } = useAssistantSettings();

const assistantUiFlags = useMapGetter('captainAssistants/getUIFlags');
const uiFlags = useMapGetter('captainInboxes/getUIFlags');
const isFetchingAssistant = computed(() => assistantUiFlags.value.fetchingItem);
const isFetching = computed(() => uiFlags.value.fetchingList);

const captainInboxes = useMapGetter('captainInboxes/getRecords');

const selectedInbox = ref(null);
const disconnectInboxDialog = ref(null);

const handleDelete = () => {
  disconnectInboxDialog.value?.dialogRef.open();
};

const handleCreate = () => {
  isConnectPanelOpen.value = true;
};

const handleAction = ({ action, id }) => {
  selectedInbox.value = captainInboxes.value.find(inbox => id === inbox.id);
  nextTick(() => {
    if (action === 'delete') {
      handleDelete();
    }
  });
};

watch(
  assistantId,
  newId => {
    if (newId) {
      store.dispatch('captainInboxes/get', {
        assistantId: newId,
      });
      store.dispatch('inboxes/get');
    }
  },
  { immediate: true }
);
</script>

<template>
  <PageLayout
    :header-title="$t('CAPTAIN.AGENT_UX.SECTIONS.CHANNELS')"
    :button-label="$t('CAPTAIN.INBOXES.ADD_NEW')"
    :button-policy="['administrator']"
    :is-fetching="isFetchingAssistant || isFetching"
    :is-empty="!captainInboxes.length"
    :show-pagination-footer="false"
    :show-know-more="false"
    :feature-flag="FEATURE_FLAGS.CAPTAIN"
    @click="handleCreate"
  >
    <template #subHeader>
      <p class="mt-1 text-sm text-n-slate-11">
        {{ $t('CAPTAIN.INBOXES.SUBHEADER') }}
      </p>
    </template>

    <template #emptyState>
      <InboxPageEmptyState @click="handleCreate" />
    </template>

    <template #body>
      <div class="flex flex-col gap-4">
        <InboxCard
          v-for="captainInbox in captainInboxes"
          :id="captainInbox.id"
          :key="captainInbox.id"
          :inbox="captainInbox"
          :assistant="assistant"
          @action="handleAction"
        />
      </div>
    </template>

    <DeleteDialog
      v-if="selectedInbox"
      ref="disconnectInboxDialog"
      :entity="selectedInbox"
      :delete-payload="{
        assistantId: assistantId,
        inboxId: selectedInbox.id,
      }"
      type="Inboxes"
      translation-key="INBOXES"
      @delete-success="selectedInbox = null"
    />

    <ConnectInboxPanel
      v-model:open="isConnectPanelOpen"
      :assistant-id="assistantId"
      :assistant-name="assistant?.name"
    />
  </PageLayout>
</template>

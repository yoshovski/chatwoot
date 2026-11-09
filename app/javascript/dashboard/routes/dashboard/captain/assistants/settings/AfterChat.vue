<script setup>
import { watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAssistantSettings } from './useAssistantSettings';
import SettingsPageLayout from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsPageLayout.vue';
import AssistantAfterChatForm from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantAfterChatForm.vue';

const { t } = useI18n();
const store = useStore();
const { assistant, assistantId, updateAssistant } = useAssistantSettings();
const inboxes = useMapGetter('captainInboxes/getRecords');

watch(
  assistantId,
  id => {
    if (id) store.dispatch('captainInboxes/get', { assistantId: id });
  },
  { immediate: true }
);
</script>

<template>
  <SettingsPageLayout :heading="t('CAPTAIN.AGENT_UX.SECTIONS.HANDOFF')">
    <AssistantAfterChatForm
      :assistant="assistant"
      :save="updateAssistant"
      :inboxes="inboxes"
    />
  </SettingsPageLayout>
</template>

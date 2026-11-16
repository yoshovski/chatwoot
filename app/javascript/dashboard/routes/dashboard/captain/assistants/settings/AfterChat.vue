<script setup>
import { useI18n } from 'vue-i18n';
import { useAssistantSettings } from './useAssistantSettings';
import { useConnectedInboxes } from './useConnectedInboxes';
import SettingsPageLayout from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsPageLayout.vue';
import AssistantAfterChatForm from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantAfterChatForm.vue';

const { t } = useI18n();
const { assistant, assistantId, updateAssistant } = useAssistantSettings();
const { inboxes } = useConnectedInboxes(assistantId);
</script>

<template>
  <SettingsPageLayout :heading="t('CAPTAIN.AGENT_UX.TABS.CHAT_ENDS')">
    <AssistantAfterChatForm
      :assistant="assistant"
      :save="updateAssistant"
      :inboxes="inboxes"
    />
  </SettingsPageLayout>
</template>

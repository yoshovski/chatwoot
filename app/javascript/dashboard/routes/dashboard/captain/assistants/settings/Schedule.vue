<script setup>
import { useI18n } from 'vue-i18n';
import { useAssistantSettings } from './useAssistantSettings';
import { useConnectedInboxes } from './useConnectedInboxes';
import SettingsPageLayout from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsPageLayout.vue';
import AssistantScheduleForm from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantScheduleForm.vue';

const { t } = useI18n();
const { assistant, assistantId, updateAssistant } = useAssistantSettings();
const { inboxes, status, retry } = useConnectedInboxes(assistantId);
</script>

<template>
  <SettingsPageLayout
    :heading="t('CAPTAIN.AGENT_UX.TABS.HOURS')"
    :description="t('CAPTAIN.ASSISTANTS.SETTINGS.WORKING_HOURS.DESCRIPTION')"
  >
    <AssistantScheduleForm
      :assistant="assistant"
      :save="updateAssistant"
      :inboxes="inboxes"
      :hours-status="status"
      @retry-hours="retry"
    />
  </SettingsPageLayout>
</template>

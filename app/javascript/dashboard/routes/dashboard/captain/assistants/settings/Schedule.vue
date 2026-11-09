<script setup>
import { useI18n } from 'vue-i18n';
import { useAssistantSettings } from './useAssistantSettings';
import SettingsPageLayout from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsPageLayout.vue';
import AssistantScheduleForm from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantScheduleForm.vue';

const { t } = useI18n();
const { assistant, updateAssistant } = useAssistantSettings();
</script>

<template>
  <SettingsPageLayout
    :heading="t('CAPTAIN.AGENT_UX.SECTIONS.CHANNELS')"
    :description="t('CAPTAIN.ASSISTANTS.SETTINGS.WORKING_HOURS.DESCRIPTION')"
  >
    <AssistantScheduleForm :assistant="assistant" @submit="updateAssistant" />
  </SettingsPageLayout>
</template>

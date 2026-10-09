<script setup>
import { useI18n } from 'vue-i18n';
import { useAssistantSettings } from './useAssistantSettings';
import SettingsPageLayout from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsPageLayout.vue';
import AssistantAfterChatForm from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantAfterChatForm.vue';

const { t } = useI18n();
const { assistant, updateAssistant } = useAssistantSettings();
</script>

<template>
  <SettingsPageLayout
    :heading="t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.TITLE')"
    :description="t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.DESCRIPTION')"
  >
    <AssistantAfterChatForm :assistant="assistant" @submit="updateAssistant" />
  </SettingsPageLayout>
</template>

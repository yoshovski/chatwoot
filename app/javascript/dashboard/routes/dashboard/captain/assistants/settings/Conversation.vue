<script setup>
import { useI18n } from 'vue-i18n';
import { useAssistantSettings } from './useAssistantSettings';
import SettingsPageLayout from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsPageLayout.vue';
import AssistantConversationForm from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantConversationForm.vue';

const { t } = useI18n();
const { assistant, updateAssistant } = useAssistantSettings();
</script>

<template>
  <SettingsPageLayout
    :heading="t('PLATFORM_NAV.CONVERSATION')"
    :description="t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.DESCRIPTION')"
  >
    <AssistantConversationForm :assistant="assistant" :save="updateAssistant" />
  </SettingsPageLayout>
</template>

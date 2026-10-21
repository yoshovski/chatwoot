<script setup>
import { useI18n } from 'vue-i18n';
import { useAssistantSettings } from './useAssistantSettings';
import SettingsPageLayout from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsPageLayout.vue';
import AssistantAfterChatForm from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantAfterChatForm.vue';

const { t } = useI18n();
const { assistant, updateAssistant } = useAssistantSettings();
</script>

<template>
  <SettingsPageLayout :heading="t('PLATFORM_NAV.AFTER_CHAT')">
    <AssistantAfterChatForm :assistant="assistant" :save="updateAssistant" />
  </SettingsPageLayout>
</template>

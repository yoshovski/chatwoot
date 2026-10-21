<script setup>
import { useI18n } from 'vue-i18n';
import { useAssistantSettings } from './useAssistantSettings';
import SettingsPageLayout from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsPageLayout.vue';
import AssistantHandoverForm from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantHandoverForm.vue';

const { t } = useI18n();
const { assistant, updateAssistant } = useAssistantSettings();
</script>

<template>
  <SettingsPageLayout
    :heading="t('PLATFORM_NAV.HANDOFF')"
    :description="t('PLATFORM_NAV.HANDOFF_DESC')"
  >
    <AssistantHandoverForm :assistant="assistant" @submit="updateAssistant" />
  </SettingsPageLayout>
</template>

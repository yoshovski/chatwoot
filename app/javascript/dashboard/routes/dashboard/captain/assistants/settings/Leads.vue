<script setup>
import { useI18n } from 'vue-i18n';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useAssistantSettings } from './useAssistantSettings';
import SettingsPageLayout from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsPageLayout.vue';
import AssistantLeadsForm from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantLeadsForm.vue';

const { t } = useI18n();
const { isAdmin } = useAdmin();
const { assistant, updateAssistant } = useAssistantSettings();
</script>

<template>
  <SettingsPageLayout
    :heading="t('CAPTAIN.ASSISTANTS.SETTINGS.LEADS.TITLE')"
    :description="t('CAPTAIN.ASSISTANTS.SETTINGS.LEADS.DESCRIPTION')"
  >
    <AssistantLeadsForm
      v-if="assistant?.id"
      :key="assistant.id"
      :assistant="assistant"
      :save="updateAssistant"
      :can-manage-integrations="isAdmin"
    />
  </SettingsPageLayout>
</template>

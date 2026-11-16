<script setup>
import { useI18n } from 'vue-i18n';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

const message = defineModel({ type: String, default: '' });
const { t } = useI18n();
const MAX_LENGTH = 500;
</script>

<template>
  <TextArea
    v-model="message"
    :label="t('CAPTAIN.AGENT_UX.CONFIGURATION.RULES.DECLINE_LABEL')"
    :max-length="MAX_LENGTH"
    show-character-count
    :placeholder="
      t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.OFF_LIMITS.PLACEHOLDER')
    "
  />
</template>

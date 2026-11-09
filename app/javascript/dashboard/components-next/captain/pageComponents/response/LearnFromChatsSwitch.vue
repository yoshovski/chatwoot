<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAssistantSettings } from 'dashboard/routes/dashboard/captain/assistants/settings/useAssistantSettings';
import SettingsCard from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsCard.vue';
import SettingsSwitchRow from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsSwitchRow.vue';

// Lives next to the suggestions it produces (was under After chat). A single switch saves at once.
const { t } = useI18n();
const { assistant, updateAssistant } = useAssistantSettings();

const enabled = computed({
  get: () => Boolean(assistant.value?.config?.feature_faq),
  set: value =>
    updateAssistant({
      config: { ...assistant.value.config, feature_faq: value },
    }),
});
</script>

<template>
  <SettingsCard v-if="assistant" class="mb-4">
    <SettingsSwitchRow
      v-model="enabled"
      class="!py-0"
      :title="t('CAPTAIN.AGENT_UX.SUGGESTIONS.LEARN_TITLE')"
      :description="
        t('CAPTAIN.AGENT_UX.SUGGESTIONS.LEARN_DESC', { name: assistant.name })
      "
    />
  </SettingsCard>
</template>

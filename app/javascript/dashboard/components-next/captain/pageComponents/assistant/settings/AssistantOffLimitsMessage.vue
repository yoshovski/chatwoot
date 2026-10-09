<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import SettingsCard from './SettingsCard.vue';

const props = defineProps({
  assistant: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();

const MAX_LENGTH = 500;
const message = ref('');

watch(
  () => props.assistant?.config?.off_limits_message,
  value => {
    message.value = value || '';
  },
  { immediate: true }
);

const save = () =>
  emit('submit', {
    config: {
      ...props.assistant.config,
      off_limits_message: message.value.trim(),
    },
  });
</script>

<template>
  <SettingsCard
    :title="
      t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.OFF_LIMITS.TITLE', {
        name: assistant.name,
      })
    "
    :description="t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.OFF_LIMITS.DESC')"
  >
    <div class="flex flex-col gap-3 pt-2">
      <TextArea
        v-model="message"
        :max-length="MAX_LENGTH"
        show-character-count
        :placeholder="
          t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.OFF_LIMITS.PLACEHOLDER')
        "
      />
      <div>
        <Button
          :label="t('CAPTAIN.ASSISTANTS.SETTINGS.SAVE')"
          size="sm"
          @click="save"
        />
      </div>
    </div>
  </SettingsCard>
</template>

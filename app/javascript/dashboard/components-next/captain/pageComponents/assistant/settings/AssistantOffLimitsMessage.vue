<script setup>
import { computed, ref, watch } from 'vue';
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

// Mirrors the unsaved text so the page can preview it live.
const draft = defineModel('draft', { type: String, default: '' });

const { t } = useI18n();

const MAX_LENGTH = 500;
const message = ref('');
const savedMessage = computed(
  () => props.assistant?.config?.off_limits_message || ''
);
const isDirty = computed(() => message.value.trim() !== savedMessage.value);

watch(
  savedMessage,
  value => {
    message.value = value;
  },
  { immediate: true }
);

watch(
  message,
  value => {
    draft.value = value;
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
      <div v-if="isDirty" class="flex items-center gap-2">
        <Button
          :label="t('CAPTAIN.ASSISTANTS.SETTINGS.SAVE')"
          size="sm"
          @click="save"
        />
        <Button
          :label="t('CAPTAIN.ASSISTANTS.SETTINGS.SAVE_BAR.DISCARD')"
          variant="ghost"
          color="slate"
          size="sm"
          @click="message = savedMessage"
        />
      </div>
    </div>
  </SettingsCard>
</template>

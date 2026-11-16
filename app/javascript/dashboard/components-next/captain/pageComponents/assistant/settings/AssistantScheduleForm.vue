<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import SettingsSaveBar from './SettingsSaveBar.vue';
import { useSettingsSave } from './useSettingsSave';
import RadioCard from 'dashboard/components-next/radioCard/RadioCard.vue';
import SettingsCard from './SettingsCard.vue';
import ConnectedInboxHours from './ConnectedInboxHours.vue';

const props = defineProps({
  assistant: {
    type: Object,
    default: () => ({}),
  },
  inboxes: { type: Array, default: () => [] },
  hoursStatus: { type: String, default: 'loading' },
  save: {
    type: Function,
    default: null,
  },
});

const emit = defineEmits(['submit', 'retryHours']);

const { t } = useI18n();

const RESPONSE_WINDOW = {
  ALWAYS: 'always',
  BUSINESS_HOURS: 'business_hours',
  OUTSIDE_BUSINESS_HOURS: 'outside_business_hours',
};

const OPTIONS = Object.values(RESPONSE_WINDOW);

const selected = ref(RESPONSE_WINDOW.ALWAYS);

const savedResponseWindow = computed(
  () => props.assistant?.config?.response_window || RESPONSE_WINDOW.ALWAYS
);

const isDirty = computed(() => selected.value !== savedResponseWindow.value);

const discard = () => {
  selected.value = savedResponseWindow.value;
};

watch([() => props.assistant.id, savedResponseWindow], discard, {
  immediate: true,
});

const handleSubmit = async () => {
  const payload = {
    config: { ...props.assistant.config, response_window: selected.value },
  };
  if (props.save) {
    return props.save(payload);
  }
  emit('submit', payload);
  return undefined;
};
const {
  isSaving,
  isSaved,
  saveError,
  save: saveChanges,
} = useSettingsSave(isDirty, handleSubmit);
</script>

<template>
  <div class="flex max-w-[48rem] flex-col gap-6">
    <SettingsCard
      :title="t('CAPTAIN.AGENT_UX.CONFIGURATION.CURRENT')"
      :description="
        t(
          `CAPTAIN.ASSISTANTS.FORM.SCHEDULE.${savedResponseWindow.toUpperCase()}.LABEL`
        )
      "
    />
    <div class="grid gap-3 lg:grid-cols-3" :inert="isSaving">
      <RadioCard
        v-for="option in OPTIONS"
        :id="option"
        :key="option"
        :label="
          t(`CAPTAIN.ASSISTANTS.FORM.SCHEDULE.${option.toUpperCase()}.LABEL`)
        "
        :description="
          t(`CAPTAIN.ASSISTANTS.FORM.SCHEDULE.${option.toUpperCase()}.DESC`, {
            name: assistant.name,
          })
        "
        :is-active="selected === option"
        @select="selected = $event"
      />
    </div>

    <ConnectedInboxHours
      :inboxes="inboxes"
      :status="hoursStatus"
      @retry="emit('retryHours')"
    />

    <SettingsSaveBar
      :is-dirty="isDirty"
      :is-saving="isSaving"
      :is-saved="isSaved"
      :error="saveError"
      @save="saveChanges"
      @discard="discard"
    />
  </div>
</template>

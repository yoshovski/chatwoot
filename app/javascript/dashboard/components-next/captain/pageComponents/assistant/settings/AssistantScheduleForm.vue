<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import SettingsSaveBar from './SettingsSaveBar.vue';
import RadioCard from 'dashboard/components-next/radioCard/RadioCard.vue';
import WorkingHoursChart from './WorkingHoursChart.vue';

const props = defineProps({
  assistant: {
    type: Object,
    default: () => ({}),
  },
  save: {
    type: Function,
    default: null,
  },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();

const RESPONSE_WINDOW = {
  ALWAYS: 'always',
  BUSINESS_HOURS: 'business_hours',
  OUTSIDE_BUSINESS_HOURS: 'outside_business_hours',
};

const OPTIONS = Object.values(RESPONSE_WINDOW);

const isSaving = ref(false);
const selected = ref(RESPONSE_WINDOW.ALWAYS);

const savedResponseWindow = computed(
  () => props.assistant?.config?.response_window || RESPONSE_WINDOW.ALWAYS
);

watch(
  () => props.assistant,
  newAssistant => {
    if (newAssistant) {
      selected.value =
        newAssistant.config?.response_window || RESPONSE_WINDOW.ALWAYS;
    }
  },
  { immediate: true }
);

const isDirty = computed(() => selected.value !== savedResponseWindow.value);

const discard = () => {
  selected.value = savedResponseWindow.value;
};

const handleSubmit = async () => {
  const payload = {
    config: { ...props.assistant.config, response_window: selected.value },
  };
  emit('submit', payload);
  if (props.save) {
    isSaving.value = true;
    try {
      await props.save(payload);
    } finally {
      isSaving.value = false;
    }
  }
};
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="grid gap-3 lg:grid-cols-3">
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

    <WorkingHoursChart :response-window="selected" :name="assistant.name" />

    <SettingsSaveBar
      :is-dirty="isDirty"
      :is-saving="isSaving"
      @save="handleSubmit"
      @discard="discard"
    />
  </div>
</template>

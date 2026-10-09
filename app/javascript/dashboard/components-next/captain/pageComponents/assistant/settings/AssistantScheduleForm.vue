<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import RadioCard from 'dashboard/components-next/radioCard/RadioCard.vue';
import WorkingHoursChart from './WorkingHoursChart.vue';

const props = defineProps({
  assistant: {
    type: Object,
    default: () => ({}),
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

const selected = ref(RESPONSE_WINDOW.ALWAYS);

const handleSubmit = () => {
  emit('submit', {
    config: { ...props.assistant.config, response_window: selected.value },
  });
};

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
</script>

<template>
  <div class="flex flex-col gap-4">
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
    <div>
      <Button
        :label="t('CAPTAIN.ASSISTANTS.SETTINGS.SAVE')"
        @click="handleSubmit"
      />
    </div>
  </div>
</template>

<script setup>
import FormLayout from 'dashboard/components-next/kit/FormLayout.vue';

defineProps({
  isDirty: { type: Boolean, default: false },
  isSaving: { type: Boolean, default: false },
  isSaved: { type: Boolean, default: false },
  error: { type: String, default: '' },
});

const emit = defineEmits(['save', 'discard']);
</script>

<template>
  <FormLayout
    class="!max-w-full"
    :dirty="isDirty"
    :saving="isSaving"
    :saved="isSaved"
    :error="error"
    :save-label="$t('CAPTAIN.ASSISTANTS.SETTINGS.SAVE')"
    :saved-label="$t('CAPTAIN.AGENT_UX.CONFIGURATION.SAVED')"
    guard-route-params
    @save="emit('save')"
    @discard="emit('discard')"
  />
</template>

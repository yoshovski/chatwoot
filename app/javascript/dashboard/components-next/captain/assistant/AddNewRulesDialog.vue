<script setup>
import { ref } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

defineProps({
  placeholder: { type: String, default: '' },
  buttonLabel: { type: String, default: '' },
  confirmLabel: { type: String, default: '' },
  cancelLabel: { type: String, default: '' },
});

const emit = defineEmits(['add']);
const modelValue = defineModel({ type: String, default: '' });
const dialog = ref(null);

const add = () => {
  const rule = modelValue.value.trim();
  if (!rule) return;
  emit('add', rule);
  modelValue.value = '';
  dialog.value.close();
};
</script>

<template>
  <div>
    <Button
      :label="buttonLabel"
      type="button"
      sm
      slate
      @click="dialog.open()"
    />
    <Dialog
      ref="dialog"
      :title="buttonLabel"
      :confirm-button-label="confirmLabel"
      :cancel-button-label="cancelLabel"
      :disable-confirm-button="!modelValue.trim()"
      @confirm="add"
    >
      <TextArea
        v-model="modelValue"
        :label="$t('CAPTAIN.AGENT_UX.CONFIGURATION.RULES.TEXT')"
        :placeholder="placeholder"
        min-height="6rem"
      />
    </Dialog>
  </div>
</template>

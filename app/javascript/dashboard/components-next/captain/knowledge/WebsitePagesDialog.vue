<script setup>
import { nextTick, ref } from 'vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import WebsiteSourceSelection from './WebsiteSourceSelection.vue';

defineProps({
  assistantId: { type: Number, required: true },
});
const emit = defineEmits(['saved']);
const source = ref(null);
const dialog = ref(null);

const open = async websiteSource => {
  source.value = websiteSource;
  await nextTick();
  dialog.value.open();
};
const saved = () => {
  dialog.value.close();
  emit('saved');
};
defineExpose({ open });
</script>

<template>
  <Dialog
    v-if="source"
    ref="dialog"
    width="5xl"
    :title="$t('CAPTAIN.WEBSITES.TITLE')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="source = null"
  >
    <WebsiteSourceSelection
      :key="source.id"
      :assistant-id="assistantId"
      :source-id="source.id"
      @saved="saved"
      @cancel="dialog.close()"
    />
    <template #footer />
  </Dialog>
</template>

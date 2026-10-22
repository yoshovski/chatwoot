<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  type: {
    type: String,
    required: true,
  },
  // { ids } or { select_all, filters }, see useListSelection.
  target: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['deleteSuccess']);

const { t } = useI18n();
const store = useStore();
const bulkDeleteDialogRef = ref(null);
const i18nKey = computed(() => {
  const i18nTypeMap = {
    AssistantResponse: 'RESPONSES',
    AssistantDocument: 'DOCUMENTS',
  };
  return i18nTypeMap[props.type];
});

const handleDialogConfirm = async () => {
  try {
    await store.dispatch('captainBulkActions/handleBulkDelete', {
      target: props.target,
      type: props.type,
    });

    emit('deleteSuccess');
    useAlert(t(`CAPTAIN.${i18nKey.value}.BULK_DELETE.SUCCESS_MESSAGE`));
  } catch (error) {
    useAlert(t(`CAPTAIN.${i18nKey.value}.BULK_DELETE.ERROR_MESSAGE`));
  }
  bulkDeleteDialogRef.value?.close();
};

defineExpose({ dialogRef: bulkDeleteDialogRef });
</script>

<template>
  <Dialog
    ref="bulkDeleteDialogRef"
    type="alert"
    :title="t(`CAPTAIN.${i18nKey}.BULK_DELETE.TITLE`)"
    :description="t(`CAPTAIN.${i18nKey}.BULK_DELETE.DESCRIPTION`)"
    :confirm-button-label="t(`CAPTAIN.${i18nKey}.BULK_DELETE.CONFIRM`)"
    @confirm="handleDialogConfirm"
  />
</template>

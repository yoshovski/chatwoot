<script setup>
import { ref } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import DocumentForm from './DocumentForm.vue';
import api from 'dashboard/api/captain/knowledgeSources';
import WebsiteSourceSelection from '../../knowledge/WebsiteSourceSelection.vue';

const props = defineProps({
  assistantId: {
    type: Number,
    required: true,
  },
  storeHosts: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['close', 'createSuccess']);
const { t } = useI18n();
const store = useStore();

const dialogRef = ref(null);
const websiteSource = ref(null);
const discovering = ref(false);

const i18nKey = 'CAPTAIN.DOCUMENTS.CREATE';

const handleDiscover = async details => {
  if (discovering.value) return;
  discovering.value = true;
  try {
    const { data } = await api.discover(props.assistantId, details);
    websiteSource.value = data;
    emit('createSuccess');
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('CAPTAIN.WEBSITES.LOAD_ERROR'));
  } finally {
    discovering.value = false;
  }
};
const handleWebsiteSaved = () => {
  emit('createSuccess');
  useAlert(t('CAPTAIN.WEBSITES.SAVED'));
  dialogRef.value.close();
};

const handleSubmit = async newDocument => {
  try {
    await store.dispatch('captainDocuments/create', newDocument);
    emit('createSuccess');
    useAlert(t(`${i18nKey}.SUCCESS_MESSAGE`));
    dialogRef.value.close();
  } catch (error) {
    const errorMessage =
      parseAPIErrorResponse(error) || t(`${i18nKey}.ERROR_MESSAGE`);
    useAlert(errorMessage);
  }
};

const handleClose = () => {
  emit('close');
};

const handleCancel = () => {
  dialogRef.value.close();
};

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="$t(`${i18nKey}.TITLE`)"
    :description="$t('CAPTAIN.DOCUMENTS.FORM_DESCRIPTION')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    :width="websiteSource ? '3xl' : 'lg'"
    @close="handleClose"
  >
    <DocumentForm
      v-if="!websiteSource"
      :assistant-id="assistantId"
      :store-hosts="storeHosts"
      :busy="discovering"
      @submit="handleSubmit"
      @discover="handleDiscover"
      @cancel="handleCancel"
    />
    <WebsiteSourceSelection
      v-else
      :assistant-id="assistantId"
      :source-id="websiteSource.id"
      @saved="handleWebsiteSaved"
      @cancel="handleCancel"
    />
    <template #footer />
  </Dialog>
</template>

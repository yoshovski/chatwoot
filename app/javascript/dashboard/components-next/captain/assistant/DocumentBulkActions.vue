<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import documentsAPI from 'dashboard/api/captain/document';

import BulkSelectBar from 'dashboard/components-next/captain/assistant/BulkSelectBar.vue';
import BulkDeleteDialog from 'dashboard/components-next/captain/pageComponents/BulkDeleteDialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  selectedIds: { type: Set, default: () => new Set() },
  documents: { type: Array, default: () => [] },
});

const emit = defineEmits([
  'update:selectedIds',
  'bulkSyncQueued',
  'bulkDeleteSucceeded',
  'bulkUpdated',
]);

const { t } = useI18n();
const store = useStore();

const bulkDeleteDialog = ref(null);

const isUpdating = ref(false);
const updateEnabled = async enabled => {
  isUpdating.value = true;
  const ids = props.documents
    .filter(doc => props.selectedIds.has(doc.id))
    .map(doc => doc.id);
  try {
    const results = await Promise.allSettled(
      ids.map(id => documentsAPI.update(id, { document: { enabled } }))
    );
    const failed = ids.filter(
      (id, index) => results[index].status === 'rejected'
    );
    useAlert(
      t(
        failed.length
          ? 'PLATFORM_NAV.BULK_PARTIAL'
          : 'PLATFORM_NAV.BULK_UPDATED',
        { count: ids.length - failed.length, failed: failed.length }
      )
    );
    emit('update:selectedIds', new Set(failed));
    emit('bulkUpdated');
  } finally {
    isUpdating.value = false;
  }
};

const isSyncableDocument = doc =>
  (doc.syncable ?? !doc.pdf_document) && doc.status === 'available';

const syncableSelectedIds = computed(() => {
  if (!props.selectedIds.size) return [];
  return props.documents
    .filter(doc => props.selectedIds.has(doc.id) && isSyncableDocument(doc))
    .map(doc => doc.id);
});

const hasSyncableSelection = computed(
  () => syncableSelectedIds.value.length > 0
);

const selectAllLabel = computed(() => {
  const count = props.documents.length;
  const isAllSelected = props.selectedIds.size === count && count > 0;
  return isAllSelected
    ? t('CAPTAIN.DOCUMENTS.UNSELECT_ALL', { count })
    : t('CAPTAIN.DOCUMENTS.SELECT_ALL', { count });
});

const selectedCountLabel = computed(() =>
  t('CAPTAIN.DOCUMENTS.SELECTED', { count: props.selectedIds.size })
);

const handleBulkSync = async () => {
  const ids = syncableSelectedIds.value;
  if (!ids.length) return;

  try {
    const response = await store.dispatch('captainBulkActions/handleBulkSync', {
      ids,
    });
    const queuedCount = response?.count ?? response?.ids?.length ?? 0;
    let message = t('CAPTAIN.DOCUMENTS.BULK_SYNC.ZERO_MESSAGE');

    if (queuedCount === 1) {
      message = t('CAPTAIN.DOCUMENTS.BULK_SYNC.SUCCESS_MESSAGE_ONE');
    } else if (queuedCount > 1) {
      message = t('CAPTAIN.DOCUMENTS.BULK_SYNC.SUCCESS_MESSAGE', {
        count: queuedCount,
      });
    }

    useAlert(message);
    emit('update:selectedIds', new Set());
    if (queuedCount > 0) emit('bulkSyncQueued');
  } catch (error) {
    useAlert(t('CAPTAIN.DOCUMENTS.BULK_SYNC.ERROR_MESSAGE'));
  }
};
</script>

<template>
  <div>
    <BulkSelectBar
      :model-value="selectedIds"
      :all-items="documents"
      :select-all-label="selectAllLabel"
      :selected-count-label="selectedCountLabel"
      :delete-label="$t('CAPTAIN.DOCUMENTS.BULK_DELETE_BUTTON')"
      class="w-fit"
      :class="{ 'mb-2': selectedIds.size > 0 }"
      @update:model-value="emit('update:selectedIds', $event)"
      @bulk-delete="bulkDeleteDialog.dialogRef.open()"
    >
      <template #secondaryActions>
        <Button
          :label="t('PLATFORM_NAV.ENABLE_AI')"
          size="sm"
          variant="ghost"
          color="slate"
          :disabled="isUpdating"
          @click="updateEnabled(true)"
        />
        <Button
          :label="t('PLATFORM_NAV.DISABLE_AI')"
          size="sm"
          variant="ghost"
          color="slate"
          :disabled="isUpdating"
          @click="updateEnabled(false)"
        />
        <Button
          v-if="hasSyncableSelection"
          :label="$t('CAPTAIN.DOCUMENTS.BULK_SYNC_BUTTON')"
          sm
          slate
          ghost
          icon="i-lucide-refresh-cw"
          class="!px-1.5"
          @click="handleBulkSync"
        />
      </template>
    </BulkSelectBar>
    <BulkDeleteDialog
      ref="bulkDeleteDialog"
      :bulk-ids="selectedIds"
      type="AssistantDocument"
      @delete-success="emit('bulkDeleteSucceeded')"
    />
  </div>
</template>

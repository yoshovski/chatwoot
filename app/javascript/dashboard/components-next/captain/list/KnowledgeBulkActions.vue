<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

import ListSelectionBar from './ListSelectionBar.vue';
import BulkDeleteDialog from 'dashboard/components-next/captain/pageComponents/BulkDeleteDialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  // 'AssistantDocument' or 'AssistantResponse'.
  type: { type: String, required: true },
  // The object returned by useListSelection.
  selection: { type: Object, required: true },
});
const emit = defineEmits(['updated', 'deleted', 'syncQueued']);

const { t } = useI18n();
const store = useStore();
const deleteDialog = ref(null);
const busy = ref(false);

const setEnabled = async enabled => {
  busy.value = true;
  try {
    const { count } = await store.dispatch('captainBulkActions/setEnabled', {
      type: props.type,
      target: props.selection.target(),
      enabled,
    });
    useAlert(
      t(enabled ? 'KNOWLEDGE_LIST.TURNED_ON' : 'KNOWLEDGE_LIST.TURNED_OFF', {
        count,
      })
    );
    props.selection.clear();
    emit('updated');
  } catch {
    useAlert(t('KNOWLEDGE_LIST.UPDATE_ERROR'));
  } finally {
    busy.value = false;
  }
};

const sync = async () => {
  busy.value = true;
  try {
    const { count } = await store.dispatch('captainBulkActions/handleBulkSync', {
      target: props.selection.target(),
    });
    useAlert(t('KNOWLEDGE_LIST.REFRESH_QUEUED', { count }));
    props.selection.clear();
    if (count) emit('syncQueued');
  } catch {
    useAlert(t('CAPTAIN.DOCUMENTS.BULK_SYNC.ERROR_MESSAGE'));
  } finally {
    busy.value = false;
  }
};

const onDeleted = () => {
  props.selection.clear();
  emit('deleted');
};
</script>

<template>
  <ListSelectionBar
    :count="selection.count.value"
    :busy="busy"
    @enable="setEnabled(true)"
    @disable="setEnabled(false)"
    @delete="deleteDialog.dialogRef.open()"
    @clear="selection.clear()"
  >
    <Button
      v-if="type === 'AssistantDocument'"
      :label="$t('KNOWLEDGE_LIST.REFRESH')"
      icon="i-lucide-refresh-cw"
      size="sm"
      variant="ghost"
      color="slate"
      class="!text-n-slate-1 hover:!bg-n-slate-1/15"
      :disabled="busy"
      @click="sync"
    />
  </ListSelectionBar>
  <BulkDeleteDialog
    ref="deleteDialog"
    :target="selection.target()"
    :type="type"
    @delete-success="onDeleted"
  />
</template>

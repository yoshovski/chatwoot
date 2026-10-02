<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import api from 'dashboard/api/nativeKnowledge';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import { MAX_CSV_BYTES } from './helpers';

const props = defineProps({ baseId: { type: String, required: true } });
const emit = defineEmits(['saved']);
const { t } = useI18n();
const dialog = ref();
const csv = ref('');
const result = ref(null);
const error = ref('');
const importing = ref(false);
const { run, abort, isPending } = useAbortableRequest();
let fileVersion = 0;
const reset = () => {
  fileVersion += 1;
  abort();
  csv.value = '';
  result.value = null;
  error.value = '';
};
const open = () => {
  reset();
  dialog.value.open();
};
const selectFile = async event => {
  reset();
  const version = fileVersion;
  const file = event.target.files[0];
  if (!file) return;
  if (file.size > MAX_CSV_BYTES) {
    error.value = t('NATIVE_KNOWLEDGE.CSV_LIMIT');
    return;
  }
  try {
    const content = new TextDecoder('utf-8', { fatal: true }).decode(
      await file.arrayBuffer()
    );
    if (version !== fileVersion) return;
    csv.value = content;
    const response = await run(signal =>
      api.request(
        'post',
        `/bases/${props.baseId}/csv/preview`,
        { csv: content },
        { signal }
      )
    );
    if (response && version === fileVersion) result.value = response.data;
  } catch {
    if (version === fileVersion) error.value = t('NATIVE_KNOWLEDGE.CSV_ERROR');
  }
};
const importRows = async () => {
  if (!result.value?.valid || importing.value) return;
  importing.value = true;
  try {
    await api.request('post', `/bases/${props.baseId}/csv/import`, {
      csv: csv.value,
    });
    dialog.value.close();
    emit('saved');
  } catch {
    result.value = null;
    error.value = t('NATIVE_KNOWLEDGE.IMPORT_ERROR');
  } finally {
    importing.value = false;
  }
};
defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialog"
    width="3xl"
    :title="t('NATIVE_KNOWLEDGE.IMPORT_CSV')"
    :description="t('NATIVE_KNOWLEDGE.CSV_HINT')"
    :confirm-button-label="t('NATIVE_KNOWLEDGE.IMPORT')"
    :disable-confirm-button="!result?.valid || isPending || importing"
    :is-loading="isPending || importing"
    @confirm="importRows"
    @close="reset"
  >
    <label for="knowledge-csv" class="text-sm text-n-slate-12">{{
      t('NATIVE_KNOWLEDGE.CSV_FILE')
    }}</label>
    <input
      id="knowledge-csv"
      type="file"
      accept=".csv,text/csv"
      :disabled="importing"
      class="my-3 text-sm text-n-slate-12"
      @change="selectFile"
    />
    <p v-if="error" role="alert" class="text-sm text-n-ruby-11">{{ error }}</p>
    <div v-if="result" class="max-h-[28rem] overflow-auto">
      <p class="mb-3 text-sm text-n-slate-12">
        {{
          t('NATIVE_KNOWLEDGE.PREVIEW_COUNT', {
            count: result.rows.length,
            errors: result.errors.length,
          })
        }}
      </p>
      <ul
        v-if="result.errors.length"
        class="space-y-2 text-sm text-n-ruby-11"
        role="alert"
      >
        <li v-for="issue in result.errors" :key="issue.row">
          {{ t('NATIVE_KNOWLEDGE.ROW', { row: issue.row }) }}:
          {{ issue.message }}
        </li>
      </ul>
      <div
        v-for="row in result.rows.slice(0, 20)"
        :key="row.row"
        class="my-3 rounded-lg border border-n-weak p-3"
      >
        <p class="text-xs text-n-slate-11">
          {{ t('NATIVE_KNOWLEDGE.ROW', { row: row.row }) }} ·
          {{ t(`NATIVE_KNOWLEDGE.${row.operation.toUpperCase()}`) }} ·
          {{
            t(
              row.enabled
                ? 'NATIVE_KNOWLEDGE.ENABLED'
                : 'NATIVE_KNOWLEDGE.DISABLED'
            )
          }}
        </p>
        <p
          class="whitespace-pre-wrap break-words text-sm font-medium text-n-slate-12"
        >
          {{ row.question }}
        </p>
        <p class="whitespace-pre-wrap break-words text-sm text-n-slate-11">
          {{ row.answer }}
        </p>
      </div>
      <p v-if="result.rows.length > 20" class="text-sm text-n-slate-11">
        {{ t('NATIVE_KNOWLEDGE.PREVIEW_LIMIT') }}
      </p>
    </div>
  </Dialog>
</template>

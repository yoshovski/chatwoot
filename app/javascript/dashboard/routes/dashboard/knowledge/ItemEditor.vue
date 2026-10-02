<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import api from 'dashboard/api/nativeKnowledge';
import {
  MAX_ORIGINAL_BYTES,
  MAX_TEXT_LENGTH,
  originalPayload,
} from './helpers';

const props = defineProps({ baseId: { type: String, required: true } });
const emit = defineEmits(['saved']);
const { t } = useI18n();
const dialog = ref();
const item = ref(null);
const kind = ref('faq');
const form = ref({});
const file = ref(null);
const busy = ref(false);
const error = ref('');
const isFAQ = computed(() => kind.value === 'faq');
const valid = computed(() =>
  isFAQ.value
    ? form.value.question?.length && form.value.answer?.length
    : form.value.name?.length && form.value.text?.length
);
const open = (type, record = null) => {
  kind.value = type;
  item.value = record;
  file.value = null;
  error.value = '';
  form.value = isFAQ.value
    ? {
        question: record?.revision.question || '',
        answer: record?.revision.answer || '',
        review_state: record?.review_state || 'approved',
        source_id: record?.source_id || null,
        source_revision_id: record?.revision.source_revision_id || null,
        provenance: record?.revision.provenance || { origin: 'manual' },
      }
    : {
        name: record?.name || '',
        text: record?.revision.text || '',
        source_url: record?.revision.source_url || null,
        provenance: record?.revision.provenance || { origin: 'manual' },
      };
  dialog.value.open();
};
const selectFile = event => {
  const selected = event.target.files[0];
  file.value = null;
  error.value = '';
  if (selected?.size > MAX_ORIGINAL_BYTES) {
    error.value = t('NATIVE_KNOWLEDGE.FILE_LIMIT');
    event.target.value = '';
    return;
  }
  file.value = selected;
};
const save = async () => {
  if (!valid.value || busy.value) return;
  busy.value = true;
  error.value = '';
  try {
    const body = { ...form.value };
    const record = item.value;
    const resource = isFAQ.value ? 'entries' : 'sources';
    const url = `${api.url}${record ? `/${resource}/${record.id}` : `/bases/${props.baseId}/${resource}`}`;
    if (file.value) Object.assign(body, await originalPayload(file.value));
    if (record) body.expected_version = record.version;
    await api.request(record ? 'put' : 'post', '', body, { url });
    dialog.value.close();
    emit('saved');
  } catch (e) {
    error.value = t(
      e.response?.status === 409
        ? 'NATIVE_KNOWLEDGE.CONFLICT'
        : 'NATIVE_KNOWLEDGE.SAVE_ERROR'
    );
  } finally {
    busy.value = false;
  }
};
defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialog"
    width="2xl"
    :title="t(isFAQ ? 'NATIVE_KNOWLEDGE.FAQ' : 'NATIVE_KNOWLEDGE.SOURCE')"
    :description="t('NATIVE_KNOWLEDGE.EXACT_TEXT')"
    :confirm-button-label="t('NATIVE_KNOWLEDGE.SAVE')"
    :disable-confirm-button="!valid || busy"
    :is-loading="busy"
    @confirm="save"
  >
    <div class="flex flex-col gap-4">
      <template v-if="isFAQ">
        <label class="text-sm text-n-slate-12" for="knowledge-question">{{
          t('NATIVE_KNOWLEDGE.QUESTION')
        }}</label>
        <textarea
          id="knowledge-question"
          v-model="form.question"
          :maxlength="MAX_TEXT_LENGTH"
          rows="3"
          class="w-full rounded-lg border border-n-weak bg-n-solid-1 p-3 text-sm text-n-slate-12"
        />
        <label class="text-sm text-n-slate-12" for="knowledge-answer">{{
          t('NATIVE_KNOWLEDGE.ANSWER')
        }}</label>
        <textarea
          id="knowledge-answer"
          v-model="form.answer"
          :maxlength="MAX_TEXT_LENGTH"
          rows="7"
          class="w-full rounded-lg border border-n-weak bg-n-solid-1 p-3 text-sm text-n-slate-12"
        />
        <label for="knowledge-review" class="text-sm text-n-slate-12">{{
          t('NATIVE_KNOWLEDGE.REVIEW')
        }}</label>
        <select
          id="knowledge-review"
          v-model="form.review_state"
          class="rounded-lg border border-n-weak bg-n-solid-1 p-2 text-sm text-n-slate-12"
        >
          <option value="approved">{{ t('NATIVE_KNOWLEDGE.APPROVED') }}</option>
          <option value="draft">{{ t('NATIVE_KNOWLEDGE.DRAFT') }}</option>
        </select>
      </template>
      <template v-else>
        <Input v-model="form.name" :label="t('NATIVE_KNOWLEDGE.NAME')" />
        <Input
          :model-value="form.source_url || ''"
          :label="t('NATIVE_KNOWLEDGE.URL')"
          @update:model-value="form.source_url = $event || null"
        />
        <label class="text-sm text-n-slate-12" for="knowledge-text">{{
          t('NATIVE_KNOWLEDGE.SOURCE_TEXT')
        }}</label>
        <textarea
          id="knowledge-text"
          v-model="form.text"
          :maxlength="MAX_TEXT_LENGTH"
          rows="8"
          class="w-full rounded-lg border border-n-weak bg-n-solid-1 p-3 text-sm text-n-slate-12"
        />
        <label class="text-sm text-n-slate-12" for="knowledge-original">{{
          t('NATIVE_KNOWLEDGE.ORIGINAL')
        }}</label>
        <input
          id="knowledge-original"
          type="file"
          class="text-sm text-n-slate-12"
          @change="selectFile"
        />
        <p class="text-sm text-n-slate-11">
          {{ t('NATIVE_KNOWLEDGE.ORIGINAL_HINT') }}
        </p>
      </template>
      <p v-if="error" role="alert" class="text-sm text-n-ruby-11">
        {{ error }}
      </p>
    </div>
  </Dialog>
</template>

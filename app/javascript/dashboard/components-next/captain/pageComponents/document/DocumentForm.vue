<script setup>
import { reactive, computed, ref, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { minLength, required, url } from '@vuelidate/validators';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import SegmentedChoice from 'dashboard/components-next/captain/pageComponents/assistant/settings/SegmentedChoice.vue';

const props = defineProps({
  assistantId: {
    type: Number,
    required: true,
  },
  busy: { type: Boolean, default: false },
});

const emit = defineEmits(['submit', 'discover', 'cancel']);

const MAX_PDF_SIZE = 10 * 1024 * 1024; // 10MB
const MAX_MARKDOWN_SIZE = 10 * 1024; // 10KB

const { t } = useI18n();

const formState = {
  uiFlags: useMapGetter('captainDocuments/getUIFlags'),
};

const initialState = {
  name: '',
  url: '',
  documentType: 'website',
  scanWebsite: true,
  pdfFile: null,
  markdownContent: '',
  agentsOnly: false,
  includeSubdomains: true,
};

const state = reactive({ ...initialState });
const fileInputRef = ref(null);

const validationRules = computed(() => {
  if (state.documentType === 'website') {
    return {
      url: { required, url, minLength: minLength(1) },
      pdfFile: {},
      name: {},
      markdownContent: {},
    };
  }
  if (state.documentType === 'pdf') {
    return {
      url: {},
      pdfFile: { required },
      name: {},
      markdownContent: {},
    };
  }
  return {
    url: {},
    pdfFile: {},
    name: { required, minLength: minLength(1) },
    markdownContent: { required, minLength: minLength(1) },
  };
});

const documentTypeOptions = computed(() => [
  {
    id: 'website',
    icon: 'i-lucide-globe',
    label: t('CAPTAIN.DOCUMENTS.FORM.TYPE.WEBSITE'),
  },
  {
    id: 'pdf',
    icon: 'i-lucide-file-text',
    label: t('CAPTAIN.DOCUMENTS.FORM.TYPE.FILE'),
  },
  {
    id: 'text',
    icon: 'i-lucide-align-left',
    label: t('CAPTAIN.DOCUMENTS.FORM.TYPE.TEXT'),
  },
]);

const v$ = useVuelidate(validationRules, state);

const isLoading = computed(
  () => props.busy || formState.uiFlags.value.creatingItem
);

const hasPdfFileError = computed(() => v$.value.pdfFile.$error);

const getErrorMessage = (field, errorKey) => {
  return v$.value[field]?.$error
    ? t(`CAPTAIN.DOCUMENTS.FORM.${errorKey}.ERROR`)
    : '';
};

const formErrors = computed(() => ({
  url: getErrorMessage('url', 'URL'),
  pdfFile: getErrorMessage('pdfFile', 'PDF_FILE'),
  name: getErrorMessage('name', 'NAME'),
  markdownContent: getErrorMessage('markdownContent', 'TEXT'),
}));

const submitButtonLabel = computed(() => {
  if (state.documentType === 'website') {
    return state.scanWebsite
      ? t('CAPTAIN.DOCUMENTS.FORM.SUBMIT.FIND_PAGES')
      : t('CAPTAIN.DOCUMENTS.FORM.SUBMIT.ADD_PAGE');
  }
  if (state.documentType === 'pdf') {
    return t('CAPTAIN.DOCUMENTS.FORM.SUBMIT.ADD_FILE');
  }
  return t('CAPTAIN.DOCUMENTS.FORM.SUBMIT.ADD_TEXT');
});

const handleCancel = () => emit('cancel');

const isMarkdownUpload = file =>
  file.name.toLowerCase().endsWith('.md') ||
  ['text/markdown', 'text/x-markdown'].includes(file.type);

const handleFileChange = async event => {
  const file = event.target.files[0];
  if (!file) return;

  const isPdf =
    file.type === 'application/pdf' || file.name.toLowerCase().endsWith('.pdf');
  const isMd = isMarkdownUpload(file);

  if (!isPdf && !isMd) {
    useAlert(t('CAPTAIN.DOCUMENTS.FORM.PDF_FILE.INVALID_TYPE'));
    event.target.value = '';
    return;
  }
  const maxSize = isMd ? MAX_MARKDOWN_SIZE : MAX_PDF_SIZE;
  if (file.size > maxSize) {
    useAlert(t('CAPTAIN.DOCUMENTS.FORM.PDF_FILE.TOO_LARGE'));
    event.target.value = '';
    return;
  }

  state.pdfFile = file;
  state.name = file.name.replace(/\.(pdf|md)$/i, '');
  state.markdownContent = isMd ? await file.text() : '';
};

const openFileDialog = () => {
  nextTick(() => {
    if (fileInputRef.value) {
      fileInputRef.value.click();
    }
  });
};

const prepareDocumentDetails = () => {
  const formData = new FormData();
  formData.append('document[assistant_id]', props.assistantId);
  formData.append('document[agents_only]', state.agentsOnly);

  if (state.documentType === 'website') {
    formData.append('document[external_link]', state.url);
    formData.append('document[name]', state.name || state.url);
    formData.append('document[include_linked_pages]', false);
  } else if (state.documentType === 'text') {
    formData.append('document[name]', state.name.trim());
    formData.append('document[markdown_content]', state.markdownContent);
  } else if (state.markdownContent) {
    formData.append(
      'document[name]',
      state.name || state.pdfFile.name.replace(/\.md$/i, '')
    );
    formData.append('document[markdown_content]', state.markdownContent);
  } else {
    formData.append('document[pdf_file]', state.pdfFile);
    formData.append(
      'document[name]',
      state.name || state.pdfFile.name.replace(/\.pdf$/i, '')
    );
  }

  return formData;
};

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) {
    return;
  }

  if (state.documentType === 'website' && state.scanWebsite) {
    emit('discover', {
      url: state.url,
      include_subdomains: state.includeSubdomains,
    });
    return;
  }

  emit('submit', prepareDocumentDetails());
};
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <div class="flex flex-col gap-1.5">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('CAPTAIN.DOCUMENTS.FORM.TYPE.LABEL') }}
      </span>
      <SegmentedChoice
        v-model="state.documentType"
        :label="t('CAPTAIN.DOCUMENTS.FORM.TYPE.LABEL')"
        :options="documentTypeOptions"
      />
    </div>

    <template v-if="state.documentType === 'website'">
      <Input
        v-model="state.url"
        :label="t('CAPTAIN.DOCUMENTS.FORM.URL.LABEL')"
        :placeholder="t('CAPTAIN.DOCUMENTS.FORM.URL.PLACEHOLDER')"
        :message="formErrors.url"
        :message-type="formErrors.url ? 'error' : 'info'"
      />

      <label class="flex gap-2 items-start cursor-pointer">
        <Checkbox v-model="state.scanWebsite" class="mt-0.5 shrink-0" />
        <span class="flex flex-col gap-0.5">
          <span class="text-sm text-n-slate-12">
            {{ t('CAPTAIN.DOCUMENTS.FORM.WEBSITE_MODE.SCAN_LABEL') }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ t('CAPTAIN.DOCUMENTS.FORM.WEBSITE_MODE.SCAN_HELP') }}
          </span>
        </span>
      </label>

      <Input
        v-if="!state.scanWebsite"
        v-model="state.name"
        :label="t('CAPTAIN.DOCUMENTS.FORM.NAME.LABEL')"
        :placeholder="t('CAPTAIN.DOCUMENTS.FORM.NAME.PLACEHOLDER')"
      />
    </template>

    <template v-else-if="state.documentType === 'pdf'">
      <div class="flex flex-col gap-2">
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('CAPTAIN.DOCUMENTS.FORM.PDF_FILE.LABEL') }}
        </label>
        <div class="relative">
          <input
            ref="fileInputRef"
            type="file"
            accept=".pdf,.md,text/markdown"
            class="hidden"
            @change="handleFileChange"
          />
          <Button
            type="button"
            :color="hasPdfFileError ? 'ruby' : 'slate'"
            :variant="hasPdfFileError ? 'outline' : 'solid'"
            class="!w-full !h-auto !justify-between !py-4"
            @click="openFileDialog"
          >
            <template #default>
              <div class="flex gap-2 items-center">
                <div
                  class="flex justify-center items-center w-10 h-10 rounded-lg bg-n-slate-3"
                >
                  <i class="text-xl i-lucide-file-text text-n-slate-11" />
                </div>
                <div class="flex flex-col flex-1 gap-1 items-start">
                  <p class="m-0 text-sm font-medium text-n-slate-12">
                    {{
                      state.pdfFile
                        ? state.pdfFile.name
                        : t('CAPTAIN.DOCUMENTS.FORM.PDF_FILE.CHOOSE_FILE')
                    }}
                  </p>
                  <p class="m-0 text-xs text-n-slate-11">
                    {{
                      state.pdfFile
                        ? `${(state.pdfFile.size / 1024 / 1024).toFixed(2)} MB`
                        : t('CAPTAIN.DOCUMENTS.FORM.PDF_FILE.HELP_TEXT')
                    }}
                  </p>
                </div>
              </div>

              <i class="i-lucide-upload text-n-slate-11" />
            </template>
          </Button>
        </div>
        <p v-if="formErrors.pdfFile" class="text-xs text-n-ruby-9">
          {{ formErrors.pdfFile }}
        </p>
      </div>

      <Input
        v-model="state.name"
        :label="t('CAPTAIN.DOCUMENTS.FORM.NAME.LABEL')"
        :placeholder="t('CAPTAIN.DOCUMENTS.FORM.NAME.PLACEHOLDER')"
      />
    </template>

    <template v-else>
      <Input
        v-model="state.name"
        :label="t('CAPTAIN.DOCUMENTS.FORM.NAME.REQUIRED_LABEL')"
        :placeholder="t('CAPTAIN.DOCUMENTS.FORM.NAME.PLACEHOLDER')"
        :message="formErrors.name"
        :message-type="formErrors.name ? 'error' : 'info'"
      />
      <TextArea
        v-model="state.markdownContent"
        :label="t('CAPTAIN.DOCUMENTS.FORM.TEXT.LABEL')"
        :placeholder="t('CAPTAIN.DOCUMENTS.FORM.TEXT.PLACEHOLDER')"
        :max-length="10000"
        show-character-count
        auto-height
        min-height="8rem"
        max-height="16rem"
        :message="formErrors.markdownContent"
        :message-type="formErrors.markdownContent ? 'error' : 'info'"
      />
    </template>

    <div class="flex gap-3 justify-between items-center w-full pt-1">
      <Button
        type="button"
        variant="faded"
        color="slate"
        :label="t('CAPTAIN.FORM.CANCEL')"
        class="w-full bg-n-alpha-2 text-n-blue-11 hover:bg-n-alpha-3"
        @click="handleCancel"
      />
      <Button
        type="submit"
        :label="submitButtonLabel"
        class="w-full"
        :is-loading="isLoading"
        :disabled="isLoading"
      />
    </div>
  </form>
</template>

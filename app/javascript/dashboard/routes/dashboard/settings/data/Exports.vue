<script setup>
import { computed, ref, watch } from 'vue';
import { useTimeoutPoll } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { formatBytes } from 'shared/helpers/FileHelper';
import { useAccount } from 'dashboard/composables/useAccount';
import api from 'dashboard/api/dataExports';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { download } from '../../knowledge/helpers';
import { formatDate, POLL_INTERVAL_MS } from './importStatus';

const { t } = useI18n();
const { accountId } = useAccount();
const exports = ref([]);
const exportType = ref('all');
const busy = ref(false);
const loading = ref(true);
const downloadingId = ref(null);
const error = ref('');
const dialog = ref(null);
const exportTypes = ['all', 'conversations', 'contacts', 'knowledge'];
const icons = {
  all: 'i-lucide-database',
  conversations: 'i-lucide-messages-square',
  contacts: 'i-lucide-users',
  knowledge: 'i-lucide-book-open',
};
let generation = 0;
const hasPending = computed(() =>
  exports.value.some(item => ['pending', 'processing'].includes(item.status))
);
const expired = item => new Date(item.expires_at) <= new Date();
const statusKey = item => (expired(item) ? 'expired' : item.status);
const load = async () => {
  const token = generation;
  try {
    const { data } = await api.get();
    if (token === generation) {
      exports.value = data;
      error.value = '';
    }
  } catch {
    if (token === generation) error.value = t('DATA_EXPORTS.ERROR');
  } finally {
    if (token === generation) loading.value = false;
  }
};
const open = () => dialog.value?.open();
const start = async () => {
  if (busy.value || hasPending.value) return;
  const token = generation;
  busy.value = true;
  error.value = '';
  try {
    const { data } = await api.create({ export_type: exportType.value });
    if (token !== generation) return;
    exports.value = [data, ...exports.value].slice(0, 20);
    dialog.value?.close();
  } catch (exception) {
    if (token === generation) {
      error.value =
        exception.response?.status === 409
          ? t('DATA_EXPORTS.ACTIVE')
          : t('DATA_EXPORTS.ERROR');
      if (exception.response?.status === 409) await load();
    }
  } finally {
    if (token === generation) busy.value = false;
  }
};
const save = async item => {
  const token = generation;
  downloadingId.value = item.id;
  error.value = '';
  try {
    const { data } = await api.download(item.id);
    if (token === generation) download(data, item.filename);
  } catch {
    if (token === generation) error.value = t('DATA_EXPORTS.DOWNLOAD_ERROR');
  } finally {
    if (token === generation) downloadingId.value = null;
  }
};
watch(
  accountId,
  () => {
    generation += 1;
    exports.value = [];
    error.value = '';
    loading.value = true;
    busy.value = false;
    downloadingId.value = null;
    dialog.value?.close();
    load();
  },
  { immediate: true }
);
useTimeoutPoll(
  async () => {
    if (hasPending.value && !document.hidden) await load();
  },
  POLL_INTERVAL_MS,
  { immediate: true }
);
defineExpose({ open, hasPending, load });
</script>

<template>
  <div class="flex flex-col gap-6">
    <div
      class="flex items-start gap-3 rounded-xl border border-n-weak bg-n-solid-1 p-4"
    >
      <Icon
        icon="i-lucide-file-archive"
        class="mt-0.5 size-5 shrink-0 text-n-slate-11"
      />
      <div class="flex flex-col gap-1">
        <h3 class="text-heading-3 text-n-slate-12">
          {{ t('DATA_EXPORTS.FORMAT_TITLE') }}
        </h3>
        <p class="text-body-main text-n-slate-11">
          {{ t('DATA_EXPORTS.DESCRIPTION') }}
        </p>
      </div>
    </div>
    <p v-if="error" role="alert" class="text-body-main text-n-ruby-11">
      {{ error }}
    </p>
    <p v-if="loading" role="status" class="text-body-main text-n-slate-11">
      {{ t('DATA_EXPORTS.LOADING') }}
    </p>
    <div
      v-else-if="!exports.length"
      class="flex min-h-80 flex-col items-center justify-center gap-4 rounded-xl border border-n-weak bg-n-solid-1 px-6 py-16 text-center"
    >
      <span
        class="flex size-12 items-center justify-center rounded-full bg-n-alpha-2"
      >
        <Icon icon="i-lucide-upload" class="size-5 text-n-slate-11" />
      </span>
      <div class="flex flex-col gap-1">
        <h3 class="text-heading-2 text-n-slate-12">
          {{ t('DATA_EXPORTS.EMPTY') }}
        </h3>
        <p class="max-w-sm text-body-main text-n-slate-11">
          {{ t('DATA_EXPORTS.EMPTY_DESCRIPTION') }}
        </p>
      </div>
      <Button
        size="sm"
        icon="i-lucide-plus"
        :label="t('DATA_EXPORTS.CREATE')"
        @click="open"
      />
    </div>
    <div v-else class="divide-y divide-n-weak border-t border-n-weak">
      <div
        v-for="item in exports"
        :key="item.id"
        class="flex flex-wrap items-center justify-between gap-4 py-4"
      >
        <div class="flex min-w-0 items-center gap-3">
          <span
            class="grid size-10 shrink-0 place-items-center rounded-xl border border-n-strong bg-n-alpha-3"
          >
            <Icon :icon="icons[item.export_type]" class="size-4" />
          </span>
          <div class="flex min-w-0 flex-col gap-1">
            <div class="flex flex-wrap items-center gap-2">
              <span class="text-heading-3 text-n-slate-12">{{
                t(`DATA_EXPORTS.TYPES.${item.export_type}`)
              }}</span>
              <span
                class="flex items-center gap-1.5 text-body-main text-n-slate-11"
                role="status"
              >
                <span
                  class="size-2 rounded-full"
                  :class="{
                    'bg-n-teal-9 animate-pulse': [
                      'pending',
                      'processing',
                    ].includes(statusKey(item)),
                    'bg-n-teal-9': statusKey(item) === 'completed',
                    'bg-n-ruby-9': statusKey(item) === 'failed',
                    'bg-n-slate-8': statusKey(item) === 'expired',
                  }"
                />
                {{ t(`DATA_EXPORTS.STATUS.${statusKey(item)}`) }}
              </span>
            </div>
            <span class="text-body-main text-n-slate-11">{{
              formatDate(item.created_at)
            }}</span>
            <span
              v-if="item.status === 'completed' && !expired(item)"
              class="text-body-main text-n-slate-11"
            >
              {{
                t('DATA_EXPORTS.EXPIRES', { date: formatDate(item.expires_at) })
              }}
              <template v-if="item.byte_size">
                {{
                  t('DATA_EXPORTS.FILE_SIZE', {
                    size: formatBytes(item.byte_size),
                  })
                }}
              </template>
            </span>
          </div>
        </div>
        <Button
          v-if="item.status === 'completed' && !expired(item)"
          size="sm"
          slate
          icon="i-lucide-download"
          :label="t('DATA_EXPORTS.DOWNLOAD')"
          :is-loading="downloadingId === item.id"
          :disabled="downloadingId !== null"
          @click="save(item)"
        />
        <Button
          v-else-if="['failed', 'expired'].includes(statusKey(item))"
          size="sm"
          slate
          :label="t('DATA_EXPORTS.CREATE')"
          :disabled="hasPending"
          @click="
            exportType = item.export_type;
            open();
          "
        />
      </div>
    </div>
  </div>
  <Dialog
    ref="dialog"
    width="md"
    :title="t('DATA_EXPORTS.CREATE')"
    :description="t('DATA_EXPORTS.DIALOG_DESCRIPTION')"
    :confirm-button-label="t('DATA_EXPORTS.CREATE')"
    :disable-confirm-button="busy || hasPending"
    :is-loading="busy"
    @confirm="start"
  >
    <fieldset class="flex flex-col gap-3">
      <legend class="mb-3 text-heading-3 text-n-slate-12">
        {{ t('DATA_EXPORTS.TYPE') }}
      </legend>
      <label
        v-for="type in exportTypes"
        :key="type"
        class="flex cursor-pointer items-start gap-3 rounded-xl border p-3"
        :class="
          exportType === type ? 'border-n-brand bg-n-alpha-2' : 'border-n-weak'
        "
      >
        <input
          v-model="exportType"
          type="radio"
          name="exportType"
          :value="type"
          class="mt-1"
        />
        <span class="flex flex-col gap-1">
          <span class="text-heading-3 text-n-slate-12">{{
            t(`DATA_EXPORTS.TYPES.${type}`)
          }}</span>
          <span class="text-body-main text-n-slate-11">{{
            t(`DATA_EXPORTS.CONTENTS.${type}`)
          }}</span>
        </span>
      </label>
    </fieldset>
    <p class="mt-4 text-body-main text-n-slate-11">
      {{ t('DATA_EXPORTS.EXCLUSIONS') }}
    </p>
    <p v-if="hasPending" class="mt-4 text-body-main text-n-amber-11">
      {{ t('DATA_EXPORTS.ACTIVE') }}
    </p>
    <p v-if="error" role="alert" class="mt-4 text-body-main text-n-ruby-11">
      {{ error }}
    </p>
  </Dialog>
</template>

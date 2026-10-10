<script setup>
import { computed, ref, watch } from 'vue';
import { useTimeoutPoll } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import api from 'dashboard/api/dataExports';
import Button from 'dashboard/components-next/button/Button.vue';
import { download } from '../../knowledge/helpers';

const { t } = useI18n();
const { accountId } = useAccount();
const exports = ref([]);
const exportType = ref('all');
const busy = ref(false);
const error = ref('');
let generation = 0;
const hasPending = computed(() =>
  exports.value.some(item => ['pending', 'processing'].includes(item.status))
);
const load = async () => {
  const token = generation;
  try {
    const { data } = await api.get();
    if (token === generation) exports.value = data;
  } catch {
    if (token === generation) error.value = t('DATA_EXPORTS.ERROR');
  }
};
const start = async () => {
  busy.value = true;
  error.value = '';
  try {
    await api.create({ export_type: exportType.value });
    await load();
  } catch {
    error.value = t('DATA_EXPORTS.ERROR');
  } finally {
    busy.value = false;
  }
};
const save = async item => {
  try {
    const { data } = await api.download(item.id);
    download(data, `account-export-${item.id}.tar.gz`);
  } catch {
    error.value = t('DATA_EXPORTS.ERROR');
  }
};
watch(
  accountId,
  () => {
    generation += 1;
    exports.value = [];
    error.value = '';
    load();
  },
  { immediate: true }
);
useTimeoutPoll(
  async () => {
    if (hasPending.value) await load();
  },
  5000,
  { immediate: true }
);
</script>

<template>
  <section class="flex flex-col gap-6 p-6 overflow-auto">
    <div>
      <h1 class="text-xl font-medium text-n-slate-12">
        {{ t('DATA_EXPORTS.TITLE') }}
      </h1>
      <p class="text-n-slate-11">{{ t('DATA_EXPORTS.DESCRIPTION') }}</p>
    </div>
    <p class="text-sm text-n-slate-11">{{ t('DATA_EXPORTS.EXCLUSIONS') }}</p>
    <div class="flex items-center gap-3">
      <select
        v-model="exportType"
        :aria-label="t('DATA_EXPORTS.TYPE')"
        class="rounded-lg border border-n-weak bg-n-background"
      >
        <option
          v-for="type in ['all', 'conversations', 'contacts', 'knowledge']"
          :key="type"
          :value="type"
        >
          {{ t(`DATA_EXPORTS.TYPES.${type}`) }}
        </option>
      </select>
      <Button
        :label="t('DATA_EXPORTS.CREATE')"
        :is-loading="busy"
        :disabled="hasPending"
        @click="start"
      />
    </div>
    <p v-if="error" role="alert" class="text-n-ruby-11">{{ error }}</p>
    <div
      v-for="item in exports"
      :key="item.id"
      class="flex items-center justify-between gap-4 p-4 border rounded-xl border-n-weak"
    >
      <div class="flex flex-col gap-1">
        <span>{{
          t('DATA_EXPORTS.ITEM', {
            type: t(`DATA_EXPORTS.TYPES.${item.export_type}`),
            date: new Date(item.created_at).toLocaleString(),
          })
        }}</span
        ><span class="text-sm text-n-slate-11">{{
          t(`DATA_EXPORTS.STATUS.${item.status}`)
        }}</span>
      </div>
      <Button
        v-if="
          item.status === 'completed' && new Date(item.expires_at) > new Date()
        "
        :label="t('DATA_EXPORTS.DOWNLOAD')"
        @click="save(item)"
      />
    </div>
  </section>
</template>

<script setup>
// Translation keys are selected from the fixed mappings in this screen.
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys */
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import ContactsAPI from 'dashboard/api/contacts';

const model = defineModel({ type: String, default: '' });
const { t } = useI18n();
const choices = ref([]);
const error = ref(false);
const loading = ref(true);
const names = {
  all: 'CUSTOMERS.SEGMENTS.ALL',
  online: 'CUSTOMERS.SEGMENTS.ONLINE',
  leads: 'CUSTOMERS.SEGMENTS.LEADS',
  new: 'CUSTOMERS.SEGMENTS.NEW',
  waiting: 'CUSTOMERS.SEGMENTS.WAITING',
};
onMounted(async () => {
  try {
    choices.value = (await ContactsAPI.segments()).data.payload;
  } catch {
    error.value = true;
  } finally {
    loading.value = false;
  }
});
</script>

<template>
  <div class="min-w-0">
    <select
      v-model="model"
      :aria-label="t('CUSTOMERS.AUDIENCE')"
      :disabled="loading || error"
      class="m-0 w-full rounded-xl border-n-weak bg-n-solid-2 text-sm text-n-slate-12"
    >
      <option value="">{{ t('CUSTOMERS.EVERYONE') }}</option>
      <option
        v-if="model && !choices.some(item => item.id === model)"
        :value="model"
        disabled
      >
        {{ t('CUSTOMERS.MISSING_SEGMENT') }}
      </option>
      <option v-for="segment in choices" :key="segment.id" :value="segment.id">
        {{ segment.built_in ? t(names[segment.id]) : segment.name }}
      </option>
    </select>
    <p v-if="error" role="alert" class="mb-0 mt-1 text-xs text-n-ruby-11">
      {{ t('CUSTOMERS.SEGMENT_LOAD_ERROR') }}
    </p>
  </div>
</template>

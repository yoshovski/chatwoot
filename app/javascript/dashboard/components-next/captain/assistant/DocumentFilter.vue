<script setup>
import { computed, ref } from 'vue';

import DocumentFiltersBar from 'dashboard/components-next/captain/assistant/DocumentFiltersBar.vue';

const props = defineProps({
  // Website sync states do not apply to uploaded files or text.
  showStatus: { type: Boolean, default: true },
});
const emit = defineEmits(['change']);

const status = ref(null);
const sort = ref('recently_updated');

const hasActiveFilters = computed(() => Boolean(status.value));

const buildParams = (page = 1) => {
  const params = { page };
  if (status.value && props.showStatus) params.filter = status.value;
  if (sort.value) params.sort = sort.value;
  return params;
};

const handleStatusSelect = statusKey => {
  status.value = statusKey;
  emit('change');
};

const handleSortSelect = sortKey => {
  sort.value = sortKey;
  emit('change');
};

const reset = () => {
  status.value = null;
  sort.value = 'recently_updated';
};

defineExpose({ buildParams, reset, hasActiveFilters });
</script>

<template>
  <DocumentFiltersBar
    :show-status="showStatus"
    :active-status-filter="status"
    :active-sort="sort"
    @select-status="handleStatusSelect"
    @select-sort="handleSortSelect"
  />
</template>

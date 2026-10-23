<script setup>
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import { LIST_COLUMNS } from './listColumns';

defineProps({
  selection: { type: Object, required: true },
  // Label of the first column, e.g. "Name" or "Question".
  label: { type: String, required: true },
  // Keys of LIST_COLUMNS shown after the first column, in row order.
  columns: { type: Array, required: true },
  selectable: { type: Boolean, default: true },
});

const COLUMN_LABELS = {
  status: 'KNOWLEDGE_LIST.COLUMNS.STATUS',
  from: 'KNOWLEDGE_LIST.COLUMNS.FROM',
  updated: 'KNOWLEDGE_LIST.COLUMNS.UPDATED',
  inUse: 'KNOWLEDGE_LIST.COLUMNS.IN_USE',
  actions: '',
};
</script>

<template>
  <div
    class="flex items-center gap-3 px-4 py-2.5 text-xs font-medium border-b rounded-t-xl border-n-weak text-n-slate-11 bg-n-alpha-1"
  >
    <Checkbox
      v-if="selectable"
      :model-value="selection.pageSelected.value"
      :indeterminate="selection.pageIndeterminate.value"
      :aria-label="$t('KNOWLEDGE_LIST.SELECT_PAGE')"
      @update:model-value="selection.togglePage()"
    />
    <span class="flex items-center flex-1 min-w-0 gap-2">
      <span class="truncate">{{ label }}</span>
      <slot />
    </span>
    <span v-for="column in columns" :key="column" :class="LIST_COLUMNS[column]">
      <span v-if="COLUMN_LABELS[column]" class="truncate">
        {{ $t(COLUMN_LABELS[column]) }}
      </span>
    </span>
  </div>
</template>

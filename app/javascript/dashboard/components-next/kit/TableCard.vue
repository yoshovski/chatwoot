<script setup>
import { computed, ref } from 'vue';
import { picoSearch } from '@chatwoot/pico-search';
import SectionCard from './SectionCard.vue';
import SearchField from './SearchField.vue';
import DataTable from './DataTable.vue';
import EmptyState from './EmptyState.vue';

// A list page's body: one card with search and count on top, then the table, or one of its states
// (loading, error with retry, empty with the page's first action, no search results).
const props = defineProps({
  columns: { type: Array, required: true },
  rows: { type: Array, required: true },
  rowKey: { type: String, default: 'id' },
  loading: { type: Boolean, default: false },
  error: { type: Boolean, default: false },
  searchKeys: { type: Array, default: () => [] },
  searchPlaceholder: { type: String, default: '' },
  count: { type: String, default: '' },
  loadingText: { type: String, required: true },
  errorText: { type: String, required: true },
  unavailableText: { type: String, default: '' },
  retryLabel: { type: String, required: true },
  emptyTitle: { type: String, required: true },
  emptyDescription: { type: String, default: '' },
  emptyIcon: { type: String, default: 'i-lucide-inbox' },
  noResultsText: { type: String, default: '' },
});

const emit = defineEmits(['retry']);
const query = ref('');
const searchControls = ref(null);

const clearSearch = () => {
  query.value = '';
  searchControls.value?.querySelector('input')?.focus();
};

const visibleRows = computed(() => {
  const value = query.value.trim();
  if (!value || !props.searchKeys.length) return props.rows;
  return picoSearch(props.rows, value, props.searchKeys);
});
</script>

<template>
  <SectionCard>
    <p
      v-if="loading"
      class="m-0 py-10 text-center text-sm text-n-slate-11"
      role="status"
    >
      {{ loadingText }}
    </p>
    <EmptyState v-else-if="error" state="error" :title="errorText">
      <button
        type="button"
        class="text-sm font-medium text-n-blue-11 hover:underline"
        @click="emit('retry')"
      >
        {{ retryLabel }}
      </button>
    </EmptyState>
    <EmptyState
      v-else-if="unavailableText"
      state="unavailable"
      :title="unavailableText"
    >
      <slot name="unavailable" />
    </EmptyState>
    <EmptyState
      v-else-if="!rows.length"
      state="first-use"
      :icon="emptyIcon"
      :title="emptyTitle"
      :description="emptyDescription"
    >
      <slot name="empty" />
    </EmptyState>
    <template v-else>
      <div
        v-if="searchKeys.length || count"
        ref="searchControls"
        class="flex flex-wrap items-center gap-3"
      >
        <SearchField
          v-if="searchKeys.length"
          v-model="query"
          :placeholder="searchPlaceholder"
          class="flex-1 sm:max-w-xs"
        />
        <span v-if="count" class="ms-auto text-sm text-n-slate-11">
          {{ count }}
        </span>
      </div>
      <EmptyState
        v-if="!visibleRows.length"
        state="filtered"
        :title="noResultsText || $t('GENERAL.PHONE_INPUT.EMPTY_STATE')"
      >
        <button
          type="button"
          class="min-h-8 text-sm font-medium text-n-blue-11 hover:underline"
          @click="clearSearch"
        >
          {{ $t('GENERAL.CLEAR_SEARCH') }}
        </button>
      </EmptyState>
      <DataTable
        v-else
        :columns="columns"
        :rows="visibleRows"
        :row-key="rowKey"
      >
        <template v-for="(_, name) in $slots" #[name]="slotProps">
          <slot :name="name" v-bind="slotProps || {}" />
        </template>
      </DataTable>
    </template>
  </SectionCard>
</template>

import { computed, ref } from 'vue';

// Row selection for a paginated list: rows on the current page, or every row
// matching the list's filters ("Select all N matching").
export function useListSelection({ items, total, filters }) {
  const selectedIds = ref(new Set());
  const allMatching = ref(false);

  const pageIds = computed(() => items.value.map(item => item.id));
  const selectedOnPage = computed(
    () => pageIds.value.filter(id => selectedIds.value.has(id)).length
  );
  const pageSelected = computed(
    () =>
      allMatching.value ||
      (pageIds.value.length > 0 &&
        selectedOnPage.value === pageIds.value.length)
  );
  const pageIndeterminate = computed(
    () => !pageSelected.value && selectedOnPage.value > 0
  );
  const count = computed(() =>
    allMatching.value ? total.value : selectedIds.value.size
  );
  const canSelectMatching = computed(
    () =>
      pageSelected.value &&
      !allMatching.value &&
      total.value > pageIds.value.length
  );

  // 'on', 'off' or 'mixed' for the "Use in answers" switch. With every matching
  // row selected only the loaded page is known, so it stands in for the rest.
  const enabledState = computed(() => {
    const rows = items.value.filter(
      item => allMatching.value || selectedIds.value.has(item.id)
    );
    const onCount = rows.filter(item => item.enabled !== false).length;
    if (onCount === rows.length) return 'on';
    return onCount === 0 ? 'off' : 'mixed';
  });

  const isSelected = id => allMatching.value || selectedIds.value.has(id);

  const clear = () => {
    selectedIds.value = new Set();
    allMatching.value = false;
  };

  const toggle = id => {
    const next = allMatching.value
      ? new Set(pageIds.value)
      : new Set(selectedIds.value);
    allMatching.value = false;
    next[next.has(id) ? 'delete' : 'add'](id);
    selectedIds.value = next;
  };

  const togglePage = () => {
    if (pageSelected.value) {
      clear();
      return;
    }
    selectedIds.value = new Set([...selectedIds.value, ...pageIds.value]);
  };

  const selectMatching = () => {
    allMatching.value = true;
  };

  // The bulk_actions payload for the current selection.
  const target = () =>
    allMatching.value
      ? { select_all: true, filters: filters() }
      : { ids: [...selectedIds.value] };

  return {
    selectedIds,
    allMatching,
    pageSelected,
    pageIndeterminate,
    count,
    canSelectMatching,
    enabledState,
    isSelected,
    clear,
    toggle,
    togglePage,
    selectMatching,
    target,
  };
}

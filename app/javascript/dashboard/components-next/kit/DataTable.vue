<script setup>
// The one table: a quiet header row, rows split by thin lines, actions at the end.
// A cell is plain text from `row[column.key]` unless the page fills the `cell-<key>` slot.
defineProps({
  columns: {
    type: Array,
    required: true,
    // [{ key, label, end?: true, hideLabel?: true, class?: '' }]
  },
  rows: { type: Array, required: true },
  rowKey: { type: String, default: 'id' },
});
</script>

<template>
  <div class="-mx-5 overflow-x-auto">
    <table class="w-full min-w-[36rem] border-collapse text-sm">
      <thead>
        <tr class="border-b border-n-weak">
          <th
            v-for="column in columns"
            :key="column.key"
            class="px-3 py-2 text-xs font-medium text-n-slate-11 first:ps-5 last:pe-5"
            :class="[column.end ? 'text-end' : 'text-start', column.class]"
          >
            <slot :name="`head-${column.key}`" :column="column">
              <span :class="{ 'sr-only': column.hideLabel }">
                {{ column.label }}
              </span>
            </slot>
          </th>
        </tr>
      </thead>
      <tbody class="divide-y divide-n-weak">
        <tr v-for="row in rows" :key="row[rowKey]" class="hover:bg-n-alpha-1">
          <td
            v-for="column in columns"
            :key="column.key"
            class="px-3 py-3 align-middle text-n-slate-12 first:ps-5 last:pe-5"
            :class="[column.end ? 'text-end' : 'text-start', column.class]"
          >
            <slot :name="`cell-${column.key}`" :row="row">
              {{ row[column.key] }}
            </slot>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

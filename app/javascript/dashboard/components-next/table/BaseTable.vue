<script setup>
import { computed } from 'vue';

const props = defineProps({
  headers: {
    type: Array,
    default: () => [],
  },
  items: {
    type: Array,
    default: () => [],
  },
  noDataMessage: {
    type: String,
    default: '',
  },
  loading: {
    type: Boolean,
    default: false,
  },
  card: {
    type: Boolean,
    default: true,
  },
});

const hasHeaderSlot = computed(() => !!props.headers.length);
const showHeaders = computed(
  () => hasHeaderSlot.value && props.items.length > 0
);
</script>

<template>
  <div
    class="w-full overflow-x-auto"
    :class="
      card
        ? 'rounded-card bg-n-solid-2 shadow-card outline outline-1 -outline-offset-1 outline-n-container'
        : ''
    "
  >
    <table class="min-w-full table-auto divide-y divide-n-weak">
      <thead
        v-if="showHeaders"
        :class="
          card
            ? 'border-b border-n-weak bg-n-solid-1'
            : 'border-t border-n-weak'
        "
      >
        <tr>
          <th
            v-for="(header, index) in headers"
            :key="index"
            class="text-start capitalize"
            :class="
              card
                ? 'px-3 py-3 text-xs font-medium text-n-slate-11 first:ps-5 last:pe-5'
                : 'py-4 ltr:pr-4 rtl:pl-4 text-heading-3 text-n-slate-12'
            "
          >
            <slot :name="`header-${index}`" :header="header">
              {{ header }}
            </slot>
          </th>
        </tr>
      </thead>
      <tbody
        class="divide-y divide-n-weak text-n-slate-11"
        :class="
          card
            ? '[&_td]:px-3 [&_td]:py-3.5 [&_td:first-child]:ps-5 [&_td:last-child]:pe-5 [&_tr]:transition-colors [&_tr:hover]:bg-n-alpha-1'
            : ''
        "
      >
        <template v-if="items.length">
          <slot name="row" :items="items" />
        </template>
        <tr v-else-if="noDataMessage && !loading">
          <td
            :colspan="headers.length || 1"
            class="py-20 text-center text-body-main !text-base text-n-slate-11"
          >
            {{ noDataMessage }}
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

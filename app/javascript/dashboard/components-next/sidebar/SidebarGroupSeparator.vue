<script setup>
import Icon from 'next/icon/Icon.vue';
import SidebarSortMenu from './SidebarSortMenu.vue';

defineProps({
  collapsible: { type: Boolean, default: false },
  isExpanded: { type: Boolean, default: true },
  label: { type: String, default: '' },
  sortOptions: { type: Array, default: () => [] },
  activeSort: { type: String, default: '' },
});

const emit = defineEmits(['toggle', 'update-sort']);
</script>

<template>
  <div class="flex h-8 min-w-0 items-center gap-1 ps-2.5 pe-1">
    <component
      :is="collapsible ? 'button' : 'div'"
      :type="collapsible ? 'button' : undefined"
      :aria-expanded="collapsible ? isExpanded : undefined"
      class="flex min-w-0 items-center gap-1 rounded-md p-0 text-start text-[0.8125rem] font-semibold text-n-slate-12 select-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
      @click.stop="collapsible ? emit('toggle') : undefined"
    >
      <span class="truncate">{{ label }}</span>
      <Icon
        v-if="collapsible"
        :icon="isExpanded ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'"
        class="size-3.5 shrink-0 text-n-slate-10"
      />
    </component>
    <div
      v-if="sortOptions.length"
      class="ms-auto opacity-0 transition-opacity focus-within:opacity-100 group-hover/sidebar-section:opacity-100"
    >
      <SidebarSortMenu
        :active-sort="activeSort"
        :options="sortOptions"
        @sort="sortBy => emit('update-sort', sortBy)"
      />
    </div>
  </div>
</template>

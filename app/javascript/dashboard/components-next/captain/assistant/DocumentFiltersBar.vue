<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';
import { usePolicy } from 'dashboard/composables/usePolicy';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const props = defineProps({
  // Sync states only apply to websites, so files show no status menu.
  showStatus: { type: Boolean, default: true },
  activeStatusFilter: { type: String, default: null },
  activeSort: { type: String, default: 'recently_updated' },
});

const emit = defineEmits(['selectStatus', 'selectSort']);

const { t } = useI18n();
const { checkPermissions } = usePolicy();

const openMenu = ref(null);
const canViewUsage = computed(() => checkPermissions(['administrator']));

const MENU_CONFIG = [
  {
    key: 'status',
    activeKey: 'activeStatusFilter',
    dropdownClass: 'min-w-52',
    options: [
      { labelKey: 'STATUS.ANY', value: null, icon: 'i-lucide-circle-dashed' },
      {
        labelKey: 'STATUS.ON',
        value: 'enabled',
        icon: 'i-lucide-toggle-right',
      },
      {
        labelKey: 'STATUS.OFF',
        value: 'disabled',
        icon: 'i-lucide-toggle-left',
      },
      {
        labelKey: 'STATUS.UPDATED',
        value: 'synced',
        icon: 'i-lucide-check-circle',
      },
      {
        labelKey: 'STATUS.NEEDS_UPDATE',
        value: 'stale',
        icon: 'i-lucide-clock',
      },
      {
        labelKey: 'STATUS.UPDATING',
        value: 'syncing',
        icon: 'i-lucide-refresh-cw',
      },
      {
        labelKey: 'STATUS.FAILED',
        value: 'failed',
        icon: 'i-lucide-circle-x',
      },
    ],
  },
  {
    key: 'sort',
    activeKey: 'activeSort',
    dropdownClass: 'min-w-56',
    options: [
      {
        labelKey: 'SORT.RECENTLY_UPDATED',
        value: 'recently_updated',
        icon: 'i-lucide-arrow-down-up',
      },
      {
        labelKey: 'SORT.RECENTLY_CREATED',
        value: 'recently_created',
        icon: 'i-lucide-clock',
      },
      {
        labelKey: 'SORT.MOST_USED',
        value: 'most_used',
        icon: 'i-lucide-messages-square',
      },
    ],
  },
];

const filterMenus = computed(() =>
  MENU_CONFIG.filter(menu => menu.key !== 'status' || props.showStatus).map(
    menu => {
      const active = props[menu.activeKey];
      const items = menu.options
        .filter(option => option.value !== 'most_used' || canViewUsage.value)
        .map(opt => ({
          label: t(`CAPTAIN.DOCUMENTS.FILTERS.${opt.labelKey}`),
          value: opt.value,
          icon: opt.icon,
          action: menu.key,
          isSelected: opt.value === active,
        }));
      return {
        ...menu,
        items,
        selected: items.find(item => item.isSelected) || items[0],
      };
    }
  )
);

const closeMenu = () => {
  openMenu.value = null;
};

const toggleMenu = menu => {
  openMenu.value = openMenu.value === menu ? null : menu;
};

const handleMenuAction = ({ action, value }) => {
  closeMenu();
  if (action === 'status') emit('selectStatus', value);
  else if (action === 'sort') emit('selectSort', value);
};
</script>

<template>
  <div
    v-on-click-outside="closeMenu"
    class="inline-flex flex-wrap items-center gap-2 w-fit"
  >
    <div v-for="menu in filterMenus" :key="menu.key" class="relative">
      <Button
        :icon="menu.selected.icon"
        slate
        size="sm"
        :class="{ 'bg-n-slate-9/10': openMenu === menu.key }"
        @click="toggleMenu(menu.key)"
      >
        <span class="min-w-0 truncate">{{ menu.selected.label }}</span>
        <Icon icon="i-lucide-chevron-down" class="shrink-0 size-4" />
      </Button>
      <DropdownMenu
        v-if="openMenu === menu.key"
        :menu-items="menu.items"
        :class="menu.dropdownClass"
        class="top-full mt-2 ltr:left-0 rtl:right-0"
        @action="handleMenuAction"
      />
    </div>
  </div>
</template>

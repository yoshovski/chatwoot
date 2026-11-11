<script setup>
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useSidebarContext } from './provider';
import {
  groupPlatformNavigation,
  navigationLeaves,
  activeNavigationLeaf,
  moduleForArea,
} from './platformNavigation';
import Icon from 'next/icon/Icon.vue';
import SidebarUnreadBadge from './SidebarUnreadBadge.vue';
import SidebarSubGroup from './SidebarSubGroup.vue';
import SidebarGroupLeaf from './SidebarGroupLeaf.vue';
import AssistantNavigation from './AssistantNavigation.vue';

const props = defineProps({ items: { type: Array, required: true } });
const emit = defineEmits(['navigate']);
const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { isAllowed, resolvePath } = useSidebarContext();
const lastRoutes = ref({});

const accessible = items =>
  items.flatMap(item => {
    if (item.children) {
      const children = accessible(item.children);
      return children.length ? [{ ...item, children }] : [];
    }
    return item.to && isAllowed(item.to) ? [item] : [];
  });

const modules = computed(() =>
  accessible(groupPlatformNavigation(props.items, t))
);
const activeLeaf = computed(() =>
  activeNavigationLeaf(modules.value, route, resolvePath)
);
const activeModule = computed(
  () =>
    modules.value.find(item =>
      navigationLeaves(item).includes(activeLeaf.value)
    ) ||
    moduleForArea(modules.value, route, resolvePath) ||
    modules.value[0]
);
const panelItems = computed(() => {
  const item = activeModule.value;
  return item?.children || (item ? [item] : []);
});
const mainModules = computed(() =>
  modules.value.filter(item => item.name !== 'Settings')
);
const settingsModule = computed(() =>
  modules.value.find(item => item.name === 'Settings')
);
const GROW_MODULES = ['Reports', 'Campaigns', 'Portals'];
const moduleGroups = computed(() =>
  [
    {
      name: 'work',
      items: mainModules.value.filter(
        item => !GROW_MODULES.includes(item.name)
      ),
    },
    {
      name: 'grow',
      label: t('PLATFORM_NAV.GROW'),
      items: mainModules.value.filter(item => GROW_MODULES.includes(item.name)),
    },
    {
      name: 'settings',
      items: settingsModule.value ? [settingsModule.value] : [],
    },
  ].filter(group => group.items.length)
);
const selectModule = item => {
  if (item.name === activeModule.value?.name) return;
  const remembered = lastRoutes.value[item.name];
  const target =
    remembered && isAllowed(router.resolve(remembered)) ? remembered : null;
  router.push(target || navigationLeaves(item)[0].to);
};

watch(
  () => route.fullPath,
  () => {
    if (activeModule.value) {
      lastRoutes.value[activeModule.value.name] = route.fullPath;
    }
    emit('navigate');
  }
);
watch(
  () => route.params.accountId,
  () => {
    lastRoutes.value = {};
  },
  { flush: 'sync' }
);
</script>

<template>
  <div class="flex w-[16rem] min-w-0 flex-col gap-1 bg-n-background py-3">
    <div class="flex items-center gap-2 px-4 pb-2">
      <slot name="brand" />
      <div class="min-w-0 flex-1">
        <slot name="account" />
      </div>
    </div>
    <div class="flex items-center gap-1 px-3 pb-2">
      <slot name="search" />
      <slot name="compose" />
    </div>
    <AssistantNavigation v-if="activeModule?.name === 'Captain'" />
    <nav
      :aria-label="t('PLATFORM_NAV.PRODUCT_AREAS')"
      class="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto px-3 pb-4"
    >
      <ul
        v-for="group in moduleGroups"
        :key="group.name"
        class="m-0 flex list-none flex-col gap-0.5 p-0"
      >
        <li
          v-if="group.label"
          class="px-3 pb-1 text-xs font-medium uppercase tracking-wider text-n-slate-10"
        >
          {{ group.label }}
        </li>
        <li v-for="item in group.items" :key="item.name" class="min-w-0">
          <button
            type="button"
            :aria-current="
              activeModule?.name === item.name ? 'true' : undefined
            "
            class="flex h-9 w-full items-center gap-2.5 rounded-xl px-3 text-start text-sm transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
            :class="
              activeModule?.name === item.name
                ? item.children
                  ? 'font-semibold text-n-slate-12'
                  : 'bg-n-brand/10 font-semibold text-n-blue-11'
                : 'text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12'
            "
            @click="selectModule(item)"
          >
            <Icon :icon="item.icon" class="size-[1.125rem] shrink-0" />
            <span class="min-w-0 flex-1 truncate">{{ item.label }}</span>
            <SidebarUnreadBadge
              v-if="item.badgeCount"
              :count="item.badgeCount"
            />
            <Icon
              v-else-if="item.children"
              :icon="
                activeModule?.name === item.name
                  ? 'i-lucide-chevron-down'
                  : 'i-lucide-chevron-right'
              "
              class="size-3.5 shrink-0 text-n-slate-10"
            />
          </button>
          <ul
            v-if="activeModule?.name === item.name && item.children"
            class="m-0 flex list-none flex-col gap-0.5 py-1 ps-4"
          >
            <template v-for="child in panelItems" :key="child.name">
              <SidebarSubGroup
                v-if="child.children"
                :name="`${activeModule.name}:${child.name}`"
                :label="child.label"
                :icon="child.icon || 'i-lucide-folder'"
                :children="child.children"
                :active-child="
                  child.children.includes(activeLeaf) ? activeLeaf : undefined
                "
                is-expanded
                collapsible
                :sort-options="child.sortOptions"
                :active-sort="child.activeSort"
                @update-sort="child.onSortChange?.($event)"
              />
              <SidebarGroupLeaf
                v-else
                v-bind="child"
                :active="activeLeaf === child"
                hide-tree-line
              />
            </template>
          </ul>
        </li>
      </ul>
    </nav>
    <div class="px-3">
      <slot name="profile" />
    </div>
  </div>
</template>

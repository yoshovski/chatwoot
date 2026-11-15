<script setup>
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { onClickOutside } from '@vueuse/core';
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

// Design step (T32): a = fixed panel, b = flyout panel, c = collapsible panel.
const readVariant = () => {
  if (!import.meta.env.DEV) return 'c';
  const value = new URLSearchParams(window.location.search).get('co_variant');
  return ['a', 'b', 'c'].includes(value) ? value : 'c';
};
const variant = readVariant();

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

// The rail order is fixed: work tools, then the grow tools, then Settings.
const GROW_MODULES = ['Reports', 'Campaigns', 'Portals'];
const mainModules = computed(() =>
  modules.value.filter(item => item.name !== 'Settings')
);
const railGroups = computed(() =>
  [
    mainModules.value.filter(item => !GROW_MODULES.includes(item.name)),
    mainModules.value.filter(item => GROW_MODULES.includes(item.name)),
  ].filter(group => group.length)
);
const settingsModule = computed(() =>
  modules.value.find(item => item.name === 'Settings')
);

const readCollapsed = () => {
  try {
    return JSON.parse(localStorage.getItem('co-nav-collapsed') || '{}');
  } catch {
    return {};
  }
};
const collapsed = ref(variant === 'c' ? readCollapsed() : {});
const toggleCollapsed = name => {
  collapsed.value = { ...collapsed.value, [name]: !collapsed.value[name] };
  try {
    localStorage.setItem('co-nav-collapsed', JSON.stringify(collapsed.value));
  } catch {
    // Remembering the choice is a convenience; the toggle still works.
  }
};

const flyoutModule = ref(null);
const panelModule = computed(() =>
  variant === 'b' ? flyoutModule.value : activeModule.value
);
const panelItems = computed(() => panelModule.value?.children || []);
// A section without pages (Home) is the page itself: no panel, full width.
const showPanel = computed(
  () =>
    Boolean(panelModule.value?.children) &&
    !(variant === 'c' && collapsed.value[panelModule.value.name])
);
const isFlyout = variant === 'b';
const panelRef = ref(null);
const railRef = ref(null);
onClickOutside(
  panelRef,
  () => {
    flyoutModule.value = null;
  },
  { ignore: [railRef, '[data-popover-content]', '.v-popper__popper'] }
);

const isActive = item => activeModule.value?.name === item.name;
const isHighlighted = item =>
  isFlyout && flyoutModule.value
    ? flyoutModule.value.name === item.name
    : isActive(item);

const tooltipFor = item => ({
  content: item.badgeCount
    ? `${item.label} · ${t('PLATFORM_NAV.UNREAD', { count: item.badgeCount })}`
    : item.label,
  placement: 'right',
  delay: { show: 300, hide: 0 },
});

const openModule = item => {
  const remembered = lastRoutes.value[item.name];
  const target =
    remembered && isAllowed(router.resolve(remembered)) ? remembered : null;
  router.push(target || navigationLeaves(item)[0].to);
};
const selectModule = item => {
  if (isFlyout && item.children) {
    flyoutModule.value = flyoutModule.value?.name === item.name ? null : item;
    return;
  }
  flyoutModule.value = null;
  if (variant === 'c' && collapsed.value[item.name] && isActive(item)) {
    toggleCollapsed(item.name);
    return;
  }
  if (isActive(item)) return;
  openModule(item);
};

watch(
  () => route.fullPath,
  () => {
    if (activeModule.value) {
      lastRoutes.value[activeModule.value.name] = route.fullPath;
    }
    flyoutModule.value = null;
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
  <nav
    ref="railRef"
    :aria-label="t('PLATFORM_NAV.PRODUCT_AREAS')"
    class="flex w-16 shrink-0 flex-col items-center gap-3 bg-n-background py-3"
    :class="{ 'border-e border-n-weak': showPanel && !isFlyout }"
  >
    <div class="flex flex-col items-center">
      <slot name="account" />
      <slot name="compose" />
    </div>
    <div
      class="flex min-h-0 flex-1 flex-col items-center gap-4 overflow-y-auto px-3 pt-1"
    >
      <ul
        v-for="(group, index) in railGroups"
        :key="index"
        class="m-0 flex list-none flex-col gap-1 p-0"
      >
        <li v-for="item in group" :key="item.name">
          <button
            v-tooltip="tooltipFor(item)"
            type="button"
            :aria-label="item.label"
            :aria-current="isActive(item) ? 'true' : undefined"
            :aria-expanded="
              isFlyout && item.children
                ? flyoutModule?.name === item.name
                : undefined
            "
            class="relative flex size-10 items-center justify-center rounded-xl transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
            :class="
              isHighlighted(item)
                ? 'bg-n-brand/10 text-n-blue-11'
                : 'text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12'
            "
            @click="selectModule(item)"
          >
            <Icon :icon="item.icon" class="size-5" />
            <SidebarUnreadBadge
              v-if="item.badgeCount"
              :count="item.badgeCount"
              class="absolute -end-1 -top-1 ring-2 ring-n-background"
            />
          </button>
        </li>
      </ul>
    </div>
    <button
      v-if="settingsModule"
      v-tooltip="tooltipFor(settingsModule)"
      type="button"
      :aria-label="settingsModule.label"
      :aria-current="isActive(settingsModule) ? 'true' : undefined"
      class="flex size-10 shrink-0 items-center justify-center rounded-xl transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
      :class="
        isHighlighted(settingsModule)
          ? 'bg-n-brand/10 text-n-blue-11'
          : 'text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12'
      "
      @click="selectModule(settingsModule)"
    >
      <Icon :icon="settingsModule.icon" class="size-5" />
    </button>
    <slot name="profile" />
  </nav>
  <section
    v-if="showPanel"
    ref="panelRef"
    class="flex w-60 min-w-0 flex-col bg-n-background"
    :class="
      isFlyout
        ? 'absolute inset-y-0 z-50 border-x border-n-weak shadow-lg start-16'
        : ''
    "
  >
    <div class="flex h-14 shrink-0 items-center justify-between gap-2 px-4">
      <h2
        class="m-0 min-w-0 truncate text-base font-semibold text-n-slate-12"
        :title="panelModule.label"
      >
        {{ panelModule.label }}
      </h2>
      <div class="flex shrink-0 items-center gap-0.5">
        <slot
          v-if="panelModule.name === 'Conversation'"
          name="conversationTools"
        />
        <button
          v-if="variant === 'c'"
          v-tooltip.bottom="t('PLATFORM_NAV.HIDE_MENU')"
          type="button"
          :aria-label="t('PLATFORM_NAV.HIDE_MENU')"
          class="grid size-8 place-items-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12"
          @click="toggleCollapsed(panelModule.name)"
        >
          <Icon icon="i-lucide-panel-left-close" class="size-4" />
        </button>
      </div>
    </div>
    <AssistantNavigation v-if="panelModule.name === 'Captain'" />
    <nav
      :aria-label="t('PLATFORM_NAV.SECTION_NAVIGATION')"
      class="min-h-0 flex-1 overflow-y-auto px-2 pb-5"
    >
      <ul class="m-0 flex list-none flex-col gap-0.5 p-0">
        <template v-for="child in panelItems" :key="child.name">
          <SidebarSubGroup
            v-if="child.children"
            :name="`${panelModule.name}:${child.name}`"
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
    </nav>
  </section>
</template>

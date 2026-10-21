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
  <nav
    :aria-label="t('PLATFORM_NAV.PRODUCT_AREAS')"
    class="flex w-[3.75rem] shrink-0 flex-col items-center gap-3 border-e border-n-weak bg-n-background py-3"
  >
    <slot name="brand" />
    <div class="flex min-h-0 flex-1 flex-col gap-1 overflow-y-auto px-2">
      <button
        v-for="item in mainModules"
        :key="item.name"
        v-tooltip.right="item.label"
        type="button"
        :aria-label="item.label"
        :aria-current="activeModule?.name === item.name ? 'true' : undefined"
        class="relative flex size-10 shrink-0 items-center justify-center rounded-lg transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
        :class="
          activeModule?.name === item.name
            ? 'bg-n-brand/10 text-n-blue-text'
            : 'text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12'
        "
        @click="selectModule(item)"
      >
        <Icon :icon="item.icon" class="size-5" />
        <SidebarUnreadBadge
          v-if="item.badgeCount"
          :count="item.badgeCount"
          class="absolute -end-1 -top-1"
        />
      </button>
    </div>
    <button
      v-if="settingsModule"
      v-tooltip.right="settingsModule.label"
      type="button"
      :aria-label="settingsModule.label"
      :aria-current="activeModule?.name === 'Settings' ? 'true' : undefined"
      class="flex size-10 shrink-0 items-center justify-center rounded-lg transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
      :class="
        activeModule?.name === 'Settings'
          ? 'bg-n-brand/10 text-n-blue-text'
          : 'text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12'
      "
      @click="selectModule(settingsModule)"
    >
      <Icon :icon="settingsModule.icon" class="size-5" />
    </button>
    <slot name="profile" />
  </nav>
  <section class="flex min-w-0 flex-1 flex-col bg-n-background">
    <div class="border-b border-n-weak px-3 py-3">
      <slot name="account" />
    </div>
    <div class="flex items-center justify-between gap-2 px-4 pb-2 pt-4">
      <h2
        class="m-0 min-w-0 truncate text-lg font-semibold text-n-slate-12"
        :title="activeModule?.label"
      >
        {{ activeModule?.label }}
      </h2>
      <div class="flex shrink-0 items-center gap-0.5">
        <slot name="actions" />
      </div>
    </div>
    <AssistantNavigation v-if="activeModule?.name === 'Captain'" />
    <nav
      :aria-label="t('PLATFORM_NAV.SECTION_NAVIGATION')"
      class="min-h-0 flex-1 overflow-y-auto px-2 pb-5"
    >
      <ul class="m-0 flex list-none flex-col gap-1 p-0">
        <template v-for="item in panelItems" :key="item.name">
          <SidebarSubGroup
            v-if="item.children"
            :name="`${activeModule.name}:${item.name}`"
            :label="item.label"
            :icon="item.icon || 'i-lucide-folder'"
            :children="item.children"
            :active-child="
              item.children.includes(activeLeaf) ? activeLeaf : undefined
            "
            is-expanded
            collapsible
            :sort-options="item.sortOptions"
            :active-sort="item.activeSort"
            @update-sort="item.onSortChange?.($event)"
          />
          <SidebarGroupLeaf
            v-else
            v-bind="item"
            :active="activeLeaf === item"
            hide-tree-line
          />
        </template>
      </ul>
    </nav>
  </section>
</template>

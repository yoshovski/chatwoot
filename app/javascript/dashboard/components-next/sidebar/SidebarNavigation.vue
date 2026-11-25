<script setup>
import { computed, inject, ref, watch } from 'vue';
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
import { useNavigationLayout } from './useNavigationLayout';
import SidebarSubGroup from './SidebarSubGroup.vue';
import SidebarGroupLeaf from './SidebarGroupLeaf.vue';
import AssistantNavigation from './AssistantNavigation.vue';
import { useWebsiteChannelNavigation } from 'dashboard/composables/useWebsiteChannelNavigation';

const props = defineProps({ items: { type: Array, required: true } });
const emit = defineEmits(['navigate']);
const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { isAllowed, resolvePath } = useSidebarContext();
const lastRoutes = ref({});
const { isMobile, isCompact } = useNavigationLayout();
const websitePanelTarget = inject('websiteChannelPanelTarget', ref(null));
const {
  activePage: activeWebsitePage,
  isWebsiteSettings,
  navigation: websiteNavigation,
} = useWebsiteChannelNavigation();
const websitePanel = computed(
  () => isWebsiteSettings.value && !isMobile.value && !isCompact.value
);
// Responsive overrides never write to the user's saved desktop preference.
const temporaryPanels = ref({});
watch([isMobile, isCompact], () => {
  temporaryPanels.value = {};
});

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
const GROW_MODULES = ['Campaigns', 'Portals'];
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

// Each section's panel can be hidden to give the page the full width; the
// choice is remembered per section in this browser.
const COLLAPSED_KEY = 'co-nav-collapsed';
const readCollapsed = () => {
  try {
    return JSON.parse(localStorage.getItem(COLLAPSED_KEY) || '{}');
  } catch {
    return {};
  }
};
const collapsed = ref(readCollapsed());

const panelItems = computed(() =>
  websitePanel.value
    ? websiteNavigation.value
    : activeModule.value?.children || []
);
// A section without pages (Home) is the page itself: no panel, full width.
const PANEL_LESS = ['Settings'];
const hasPanel = item =>
  Boolean(item?.children) &&
  (!PANEL_LESS.includes(item.name) ||
    (item.name === 'Settings' && websitePanel.value));
const showPanel = computed(
  () =>
    websitePanel.value ||
    (hasPanel(activeModule.value) &&
      (isMobile.value || isCompact.value
        ? (temporaryPanels.value[activeModule.value.name] ?? isMobile.value)
        : !collapsed.value[activeModule.value.name]))
);

const toggleCollapsed = name => {
  if (isMobile.value || isCompact.value) {
    temporaryPanels.value = {
      ...temporaryPanels.value,
      [name]: !showPanel.value,
    };
    return;
  }
  collapsed.value = { ...collapsed.value, [name]: !collapsed.value[name] };
  try {
    localStorage.setItem(COLLAPSED_KEY, JSON.stringify(collapsed.value));
  } catch {
    // Remembering the choice is a convenience; the toggle still works.
  }
};

const isActive = item => activeModule.value?.name === item.name;

const MAX_BADGE = 99;
const badgeText = count => (count > MAX_BADGE ? `${MAX_BADGE}+` : count);
const isPanelHidden = item =>
  isActive(item) && hasPanel(item) && !showPanel.value;
const tooltipFor = item => {
  const parts = [item.label];
  if (item.badgeCount) {
    parts.push(t('PLATFORM_NAV.UNREAD', { count: item.badgeCount }));
  }
  return {
    content: parts.join(' · '),
    theme: 'co-nav',
    delay: { show: 250, hide: 0 },
  };
};

// Inside a panel, a gap marks where the next cluster starts: the people views
// after the standard ones, every list (channels, teams, labels, views), and the
// AI agent's setup pages between its overview and where it is live.
const CLUSTER_STARTS = [
  'Mentions',
  'captain_section_profile',
  'captain_section_channels',
];
const startsCluster = (child, index) =>
  index > 0 && (Boolean(child.children) || CLUSTER_STARTS.includes(child.name));

const openModule = item => {
  if (!hasPanel(item) && item.to) {
    router.push(item.to);
    emit('navigate');
    return;
  }
  const remembered = lastRoutes.value[item.name];
  const target =
    remembered && isAllowed(router.resolve(remembered)) ? remembered : null;
  router.push(target || navigationLeaves(item)[0].to);
};
const selectModule = item => {
  if (isPanelHidden(item)) {
    toggleCollapsed(item.name);
    return;
  }
  // A section without a panel opens its home again, e.g. back to the
  // settings cards from a settings page.
  if (isActive(item) && websitePanel.value && item.to) {
    router.push(item.to);
    emit('navigate');
    return;
  }
  if (isActive(item) && hasPanel(item)) return;
  openModule(item);
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
    class="relative flex w-[4.5rem] shrink-0 flex-col items-center gap-2 bg-n-background py-2"
  >
    <slot name="account" />
    <slot name="compose" />
    <div
      class="flex min-h-0 w-full flex-1 flex-col items-center overflow-y-auto pt-2"
    >
      <template v-for="(group, index) in railGroups" :key="index">
        <div
          v-if="index > 0"
          aria-hidden="true"
          class="my-3 h-px w-8 shrink-0 bg-n-strong"
        />
        <ul class="m-0 flex list-none flex-col items-center gap-1.5 p-0">
          <li v-for="item in group" :key="item.name">
            <button
              v-tooltip="tooltipFor(item)"
              type="button"
              :aria-label="item.label"
              :aria-current="isActive(item) ? 'true' : undefined"
              :aria-expanded="
                isActive(item) && hasPanel(item) ? showPanel : undefined
              "
              :aria-controls="
                isActive(item) && hasPanel(item)
                  ? 'co-section-panel'
                  : undefined
              "
              class="relative flex size-12 items-center justify-center rounded-2xl transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
              :class="
                isActive(item)
                  ? 'bg-n-brand/10 text-n-blue-11'
                  : 'text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12'
              "
              @click="selectModule(item)"
            >
              <Icon :icon="item.icon" class="size-6" />
              <span
                v-if="item.badgeCount"
                class="absolute end-1 top-1 grid h-[1.125rem] min-w-[1.125rem] place-items-center rounded-full bg-n-brand px-1 text-[0.6875rem] font-semibold leading-none text-white ring-2 ring-n-background"
              >
                {{ badgeText(item.badgeCount) }}
              </span>
            </button>
          </li>
        </ul>
      </template>
    </div>
    <button
      v-if="settingsModule"
      v-tooltip="tooltipFor(settingsModule)"
      type="button"
      :aria-label="settingsModule.label"
      :aria-current="isActive(settingsModule) ? 'true' : undefined"
      :aria-expanded="
        isActive(settingsModule) && hasPanel(settingsModule) && !websitePanel
          ? showPanel
          : undefined
      "
      :aria-controls="
        isActive(settingsModule) && hasPanel(settingsModule) && !websitePanel
          ? 'co-section-panel'
          : undefined
      "
      class="flex size-12 shrink-0 items-center justify-center rounded-2xl transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
      :class="
        isActive(settingsModule)
          ? 'bg-n-brand/10 text-n-blue-11'
          : 'text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12'
      "
      @click="selectModule(settingsModule)"
    >
      <Icon :icon="settingsModule.icon" class="size-6" />
    </button>
    <slot name="profile" />
    <!-- With the panel hidden, a small handle on the rail's edge, level with
    the panel title, shows it again; the page keeps the full width. -->
    <button
      v-if="hasPanel(activeModule) && !showPanel"
      v-tooltip.right="t('PLATFORM_NAV.SHOW_MENU')"
      type="button"
      :aria-label="t('PLATFORM_NAV.SHOW_MENU')"
      aria-controls="co-section-panel"
      aria-expanded="false"
      class="absolute -end-3.5 top-[1.125rem] z-30 grid size-7 place-items-center rounded-full bg-n-solid-2 text-n-slate-11 shadow-sm outline outline-1 -outline-offset-1 outline-n-container hover:text-n-slate-12 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
      @click="toggleCollapsed(activeModule.name)"
    >
      <Icon icon="i-lucide-chevrons-right" class="size-4" />
    </button>
  </nav>
  <Teleport
    :to="websitePanelTarget || 'body'"
    :disabled="!websitePanel || !websitePanelTarget"
  >
    <div
      v-if="hasPanel(activeModule)"
      class="flex shrink-0 flex-col overflow-hidden bg-n-background transition-[width] duration-200 ease-out motion-reduce:transition-none"
      :class="[
        showPanel ? 'w-56 border-n-weak' : 'w-0',
        websitePanel ? 'border-e !bg-n-solid-2' : 'border-s',
      ]"
    >
      <div
        v-if="showPanel && !websitePanel"
        class="flex h-16 w-56 shrink-0 items-center gap-1.5 ps-3 pe-3"
      >
        <button
          v-tooltip.bottom="t('PLATFORM_NAV.HIDE_MENU')"
          type="button"
          :aria-label="t('PLATFORM_NAV.HIDE_MENU')"
          aria-controls="co-section-panel"
          aria-expanded="true"
          class="grid size-8 shrink-0 place-items-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
          @click="toggleCollapsed(activeModule.name)"
        >
          <Icon icon="i-lucide-panel-left-close" class="size-[1.125rem]" />
        </button>
        <h2
          class="m-0 min-w-0 flex-1 truncate font-display text-lg font-semibold tracking-display text-n-slate-12"
          :title="activeModule.label"
        >
          {{ activeModule.label }}
        </h2>
        <div class="flex shrink-0 items-center gap-0.5">
          <slot
            v-if="activeModule.name === 'Conversation'"
            name="conversationTools"
          />
        </div>
      </div>
      <section
        v-if="showPanel"
        id="co-section-panel"
        :aria-label="websitePanel ? t('CHANNELS.TITLE') : activeModule.label"
        class="flex min-h-0 w-56 flex-1 flex-col"
        :class="{ 'pt-3': websitePanel }"
      >
        <AssistantNavigation v-if="activeModule.name === 'Captain'" />
        <nav
          :aria-label="
            websitePanel
              ? t('CHANNELS.SETTINGS')
              : t('PLATFORM_NAV.SECTION_NAVIGATION')
          "
          class="min-h-0 flex-1 overflow-y-auto px-3 pb-6"
        >
          <ul class="m-0 flex list-none flex-col gap-0.5 p-0">
            <template v-for="(child, index) in panelItems" :key="child.name">
              <li
                v-if="startsCluster(child, index)"
                aria-hidden="true"
                class="h-4 shrink-0 list-none"
              />
              <SidebarSubGroup
                v-if="child.children"
                :name="`${activeModule.name}:${child.name}`"
                :label="child.label"
                :children="child.children"
                :active-child="
                  websitePanel
                    ? activeWebsitePage
                    : child.children.includes(activeLeaf)
                      ? activeLeaf
                      : undefined
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
              />
            </template>
          </ul>
        </nav>
      </section>
    </div>
  </Teleport>
</template>

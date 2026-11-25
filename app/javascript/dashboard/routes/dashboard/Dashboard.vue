<script>
import { defineAsyncComponent, ref, computed, provide } from 'vue';

import { sectionHeadingKey } from 'dashboard/composables/useSectionHeading';
import NextSidebar from 'next/sidebar/Sidebar.vue';
import AccountBillingNotice from './settings/billing/AccountBillingNotice.vue';
import TopBarUsageIndicator from './settings/billing/components/TopBarUsageIndicator.vue';
import WootKeyShortcutModal from 'dashboard/components/widgets/modal/WootKeyShortcutModal.vue';
import AddAccountModal from 'dashboard/components/app/AddAccountModal.vue';
import UpgradePage from 'dashboard/routes/dashboard/upgrade/UpgradePage.vue';

import { useUISettings } from 'dashboard/composables/useUISettings';
import { useGuidedSetupAutoOpen } from 'dashboard/routes/dashboard/home/setup/useGuidedSetupAutoOpen';
import { useAccount } from 'dashboard/composables/useAccount';
import { useWindowSize } from '@vueuse/core';

import wootConstants from 'dashboard/constants/globals';
import { isUpgradePageBypassRoute } from 'dashboard/helper/routeHelpers';

const CommandBar = defineAsyncComponent(
  () => import('./commands/commandbar.vue')
);

const FloatingCallWidget = defineAsyncComponent(
  () => import('dashboard/components-next/call/FloatingCallWidget.vue')
);

import CopilotLauncher from 'dashboard/components-next/copilot/CopilotLauncher.vue';
import CopilotContainer from 'dashboard/components/copilot/CopilotContainer.vue';

import MobileSidebarLauncher from 'dashboard/components-next/sidebar/MobileSidebarLauncher.vue';
import { useCallsStore } from 'dashboard/stores/calls';

export default {
  components: {
    NextSidebar,
    AccountBillingNotice,
    TopBarUsageIndicator,
    CommandBar,
    WootKeyShortcutModal,
    AddAccountModal,
    UpgradePage,
    CopilotLauncher,
    CopilotContainer,
    FloatingCallWidget,
    MobileSidebarLauncher,
  },
  setup() {
    const navigationTitle = ref('');
    provide(sectionHeadingKey, navigationTitle);
    const sectionToggleTarget = ref(null);
    provide('sectionToggleTarget', sectionToggleTarget);
    const sectionPanelTarget = ref(null);
    provide('sectionPanelTarget', sectionPanelTarget);
    const upgradePageRef = ref(null);
    const { uiSettings, updateUISettings } = useUISettings();
    const { accountId } = useAccount();
    const { width: windowWidth } = useWindowSize();
    const callsStore = useCallsStore();
    useGuidedSetupAutoOpen();

    return {
      uiSettings,
      updateUISettings,
      accountId,
      navigationTitle,
      sectionToggleTarget,
      sectionPanelTarget,
      upgradePageRef,
      windowWidth,
      hasActiveCall: computed(() => callsStore.hasActiveCall),
      hasIncomingCall: computed(() => callsStore.hasIncomingCall),
    };
  },
  data() {
    return {
      conversationSection: false,
      showAccountModal: false,
      showCreateAccountModal: false,
      showShortcutModal: false,
      isMobileSidebarOpen: false,
    };
  },
  computed: {
    pageTitle() {
      if (this.navigationTitle) return this.navigationTitle;
      return this.$route.name === 'account_home'
        ? this.$t('HOME.DASHBOARD.HOME')
        : '';
    },
    isSmallScreen() {
      return this.windowWidth < wootConstants.SMALL_SCREEN_BREAKPOINT;
    },
    showUpgradePage() {
      return this.upgradePageRef?.shouldShowUpgradePage;
    },
    isAccountPaywalled() {
      return this.upgradePageRef?.isAccountPaywalled;
    },
    bypassUpgradePage() {
      return isUpgradePageBypassRoute(this.$route.name);
    },
    previouslyUsedDisplayType() {
      const {
        previously_used_conversation_display_type: conversationDisplayType,
      } = this.uiSettings;
      return conversationDisplayType;
    },
  },
  watch: {
    isSmallScreen: {
      handler() {
        const { LAYOUT_TYPES } = wootConstants;
        if (window.innerWidth <= wootConstants.SMALL_SCREEN_BREAKPOINT) {
          this.updateUISettings({
            conversation_display_type: LAYOUT_TYPES.EXPANDED,
          });
        } else {
          this.updateUISettings({
            conversation_display_type: this.previouslyUsedDisplayType,
          });
        }
      },
      immediate: true,
    },
  },
  methods: {
    updateNavigationSection({ title, conversation }) {
      this.navigationTitle = title;
      this.conversationSection = conversation;
    },
    toggleMobileSidebar() {
      this.isMobileSidebarOpen = !this.isMobileSidebarOpen;
    },
    closeMobileSidebar() {
      this.isMobileSidebarOpen = false;
    },
    openCreateAccountModal() {
      this.showAccountModal = false;
      this.showCreateAccountModal = true;
    },
    closeCreateAccountModal() {
      this.showCreateAccountModal = false;
    },
    toggleAccountModal() {
      this.showAccountModal = !this.showAccountModal;
    },
    toggleKeyShortcutModal() {
      this.showShortcutModal = true;
    },
    closeKeyShortcutModal() {
      this.showShortcutModal = false;
    },
  },
};
</script>

<template>
  <div
    class="workspace-shell flex flex-grow overflow-hidden text-n-slate-12"
    :class="{
      'inbox-workspace': $route.meta.conversationWorkspace,
    }"
  >
    <NextSidebar
      :is-mobile-sidebar-open="isMobileSidebarOpen"
      @toggle-account-modal="toggleAccountModal"
      @open-key-shortcut-modal="toggleKeyShortcutModal"
      @close-key-shortcut-modal="closeKeyShortcutModal"
      @show-create-account-modal="openCreateAccountModal"
      @close-mobile-sidebar="closeMobileSidebar"
      @section-change="updateNavigationSection"
    />

    <div
      class="flex min-w-0 flex-1 flex-col overflow-hidden"
      :inert="isSmallScreen && isMobileSidebarOpen"
    >
      <TopBarUsageIndicator
        :title="pageTitle"
        :show-plan-name="Boolean(navigationTitle)"
      >
        <template v-if="navigationTitle && conversationSection" #before-title>
          <button
            v-if="isSmallScreen"
            id="mobile-sidebar-launcher"
            type="button"
            aria-controls="co-navigation"
            :aria-expanded="isMobileSidebarOpen"
            :aria-label="$t('PLATFORM_NAV.SHOW_MENU')"
            class="grid size-8 shrink-0 place-items-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2"
            @click="toggleMobileSidebar"
          >
            <span class="i-lucide-panel-left-open size-4" aria-hidden="true" />
          </button>
          <span v-else ref="sectionToggleTarget" class="flex shrink-0" />
        </template>
        <template v-if="$route.meta.conversationWorkspace" #title-action>
          <router-link
            :to="{ name: 'search' }"
            :aria-label="$t('COMBOBOX.SEARCH_PLACEHOLDER')"
            class="me-auto grid size-8 shrink-0 place-items-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2"
          >
            <span class="i-lucide-search size-4" aria-hidden="true" />
          </router-link>
        </template>
      </TopBarUsageIndicator>
      <AccountBillingNotice />
      <div class="flex min-h-0 flex-1 flex-col md:flex-row">
        <div
          v-if="navigationTitle && (!isSmallScreen || !conversationSection)"
          ref="sectionPanelTarget"
          class="flex min-h-0 shrink-0"
        />
        <main
          class="flex flex-1 w-full min-w-0 min-h-0 px-0 overflow-hidden bg-n-surface-1"
        >
          <UpgradePage
            v-show="showUpgradePage"
            ref="upgradePageRef"
            :bypass-upgrade-page="bypassUpgradePage"
          />
          <template v-if="!showUpgradePage">
            <router-view />
            <CopilotLauncher />
            <CopilotContainer />
            <FloatingCallWidget v-if="hasActiveCall || hasIncomingCall" />
          </template>
          <CommandBar :is-paywalled="isAccountPaywalled" />
          <AddAccountModal
            :show="showCreateAccountModal"
            @close-account-create-modal="closeCreateAccountModal"
          />
          <WootKeyShortcutModal
            v-model:show="showShortcutModal"
            @close="closeKeyShortcutModal"
            @clickaway="closeKeyShortcutModal"
          />
        </main>
      </div>
      <MobileSidebarLauncher
        v-if="!navigationTitle || !conversationSection"
        :is-mobile-sidebar-open="isMobileSidebarOpen"
        @toggle="toggleMobileSidebar"
      />
    </div>
  </div>
</template>

<style scoped>
.workspace-shell {
  --workspace-gutter: 0.75rem;
}
.workspace-shell :deep(.workspace-content) {
  max-width: none;
  padding: var(--workspace-gutter);
}
.workspace-shell :deep(.workspace-widget) {
  @apply rounded-card bg-n-solid-2 shadow-card outline outline-1 -outline-offset-1 outline-n-container;
}
.workspace-shell :deep(.workspace-widget.workspace-inset) {
  padding: var(--workspace-gutter);
}
.workspace-shell :deep(.workspace-content),
.workspace-shell :deep(.workspace-widget-grid) {
  gap: var(--workspace-gutter);
}

.workspace-shell :deep(.agent-workspace > main) {
  padding-inline: 0;
}
.workspace-shell :deep(.agent-overview-width) {
  max-width: none;
}
.workspace-shell :deep(.agent-toolbar) {
  height: auto;
  padding-block: 0;
}
.workspace-shell :deep(.agent-toolbar + nav) {
  margin-block: var(--workspace-gutter) 0;
}
.workspace-shell :deep(.agent-workspace > main > div) {
  padding-block: var(--workspace-gutter) 0;
}

.workspace-shell :deep(.agent-knowledge > header) {
  container-type: inline-size;
}
.workspace-shell :deep(.agent-knowledge .agent-toolbar) {
  @apply flex-row flex-wrap items-center;
}
.workspace-shell :deep(.agent-knowledge .agent-toolbar h1) {
  @apply text-xl;
}
.workspace-shell :deep(.agent-knowledge > main > div) {
  padding-block-start: 0;
}
.workspace-shell :deep(.agent-knowledge input[type='search']) {
  @apply bg-n-solid-2;
}
@container (max-width: 35rem) {
  .workspace-shell :deep(.agent-knowledge .agent-toolbar) {
    @apply flex-col items-start gap-2;
  }
}
@container (min-width: 50rem) {
  .workspace-shell :deep(.agent-knowledge > header > div) {
    display: grid;
    grid-template-columns: auto 1fr auto;
    align-items: center;
    gap: 1.5rem;
  }
  .workspace-shell :deep(.agent-knowledge .agent-toolbar) {
    display: contents;
  }
  .workspace-shell :deep(.agent-knowledge .agent-toolbar > div:last-child) {
    grid-column: 3;
    grid-row: 1;
  }
  .workspace-shell :deep(.agent-knowledge header nav) {
    @apply m-0 gap-1 border-0;
    grid-column: 2;
    grid-row: 1;
  }
  .workspace-shell :deep(.agent-knowledge header nav a) {
    @apply rounded-lg px-3 py-2 hover:bg-n-slate-2;
  }
  .workspace-shell :deep(.agent-knowledge header nav a[aria-current='page']) {
    @apply bg-n-blue-3 text-n-blue-11;
  }
  .workspace-shell :deep(.agent-knowledge header nav a > span) {
    display: none;
  }
}
/* Leave room inside the scrollport for card outlines and keyboard focus rings. */
.workspace-shell :deep(:is(.agent-profile, .agent-handoff) > main) {
  margin-inline: calc(-1 * var(--workspace-gutter));
  padding-inline: var(--workspace-gutter);
}
.workspace-shell :deep(:is(.agent-profile, .agent-handoff) > main > div) {
  padding-block-start: 0;
  container-type: inline-size;
}
.workspace-shell :deep(:is(.agent-profile, .agent-handoff) .settings-split) {
  gap: var(--workspace-gutter);
  grid-template-columns: minmax(0, 1fr);
}
@container (min-width: 52rem) {
  .workspace-shell :deep(:is(.agent-profile, .agent-handoff) .settings-split) {
    grid-template-columns: minmax(0, 2fr) minmax(16rem, 1fr);
  }
}
.workspace-shell
  :deep(:is(.agent-profile, .agent-handoff) .settings-split > aside) {
  min-width: 0;
  top: 0;
}
.workspace-shell :deep(.agent-profile .settings-sections) {
  gap: var(--workspace-gutter);
}
.workspace-shell :deep(.agent-profile .settings-sections > section),
.workspace-shell :deep(.agent-profile .settings-chat-preview) {
  @apply rounded-card bg-n-solid-2 p-4 shadow-card outline outline-1 -outline-offset-1 outline-n-container;
}
.workspace-shell
  :deep(.agent-profile .settings-chat-preview > span:first-child) {
  @apply text-sm font-semibold text-n-slate-12;
}
.workspace-shell
  :deep(.agent-profile .settings-sections input:not([type='file'])),
.workspace-shell :deep(.agent-profile .editor-wrapper) {
  @apply bg-n-solid-2;
}
.workspace-shell :deep(:is(.agent-profile, .agent-handoff) .agent-toolbar) {
  @apply flex-row flex-wrap items-center;
}
.workspace-shell :deep(:is(.agent-profile, .agent-handoff) .agent-toolbar h1) {
  @apply text-xl;
}
.workspace-shell :deep(.agent-handoff label:has(input[type='radio'])) {
  outline-offset: -2px;
}
.workspace-shell
  :deep(.agent-handoff .settings-sections .grid:has(> div select)) {
  @apply rounded-card bg-n-solid-2 outline outline-1 -outline-offset-1 outline-n-container;
}

@media (min-width: 768px) {
  .workspace-shell {
    --inbox-folder-width: clamp(8rem, 14.5vw, 14rem);
    --inbox-queue-width: clamp(11.25rem, 25.6vw, 19rem);
    --inbox-inspector-width: clamp(10.5rem, 21.3vw, 19rem);
  }
}
@media (min-width: 768px) and (max-width: 959px) {
  .workspace-shell {
    --inbox-folder-width: clamp(7rem, 13.4vw, 8rem);
    --inbox-queue-width: clamp(10.25rem, 19.75vw, 12rem);
  }
}
@media (min-width: 768px) {
  .inbox-workspace :deep(.conversations-list-wrap) {
    container: inbox-queue / inline-size;
  }
}
@container inbox-queue (max-width: 18rem) {
  .inbox-workspace :deep(.queue-heading),
  .inbox-workspace :deep(.queue-selection-heading) {
    display: grid;
    grid-template-rows: 1fr 1fr;
    align-items: center;
    justify-content: stretch;
    gap: 0 !important;
    height: 4.5rem;
    min-height: 0;
    padding: 0 0.5rem !important;
  }
  .inbox-workspace :deep(.queue-heading > div:first-child) {
    justify-self: start;
  }
  .inbox-workspace :deep(.queue-selection-heading) {
    height: calc(4.5rem - 1px);
  }
  .inbox-workspace :deep(.queue-selection-heading > div:first-child) {
    padding-inline-start: calc(var(--selection-inset, 1.5rem) - 0.5rem);
  }
}
</style>

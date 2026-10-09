<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useToggle } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { useExactTimestamp } from 'shared/composables/useExactTimestamp';
import { usePolicy } from 'dashboard/composables/usePolicy';
import {
  isSafeHttpLink,
  formatDocumentLink,
  getDocumentDisplayPath,
} from 'shared/helpers/documentHelper';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Policy from 'dashboard/components/policy.vue';
import DocumentSyncStatus from 'dashboard/components-next/captain/assistant/DocumentSyncStatus.vue';

const props = defineProps({
  id: {
    type: Number,
    required: true,
  },
  name: {
    type: String,
    default: '',
  },
  enabled: {
    type: Boolean,
    default: true,
  },
  assistant: {
    type: Object,
    default: () => ({}),
  },
  externalLink: {
    type: String,
    required: true,
  },
  pdfDocument: {
    type: Boolean,
    default: false,
  },
  markdownDocument: {
    type: Boolean,
    default: false,
  },
  syncable: {
    type: Boolean,
    default: true,
  },
  createdAt: {
    type: Number,
    required: true,
  },
  status: {
    type: String,
    default: null,
  },
  syncStatus: {
    type: String,
    default: null,
  },
  lastSyncedAt: {
    type: Number,
    default: null,
  },
  lastSyncErrorCode: {
    type: String,
    default: null,
  },
  syncInProgress: {
    type: Boolean,
    default: false,
  },
  syncStaleAfterHours: {
    type: Number,
    default: null,
  },
  responsesCount: {
    type: Number,
    default: 0,
  },
  knowledgeState: {
    type: String,
    default: null,
  },
  isSelected: {
    type: Boolean,
    default: false,
  },
  selectable: {
    type: Boolean,
    default: false,
  },
  showSelectionControl: {
    type: Boolean,
    default: false,
  },
  showMenu: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits(['action', 'select', 'hover', 'toggle']);

const KNOWLEDGE_STATE_CHIPS = {
  searchable: {
    label: 'CAPTAIN.DOCUMENTS.KNOWLEDGE_STATE.SEARCHABLE',
    chip: 'bg-emerald-500/10 text-emerald-700 dark:text-emerald-400',
    dot: 'bg-emerald-500',
  },
  indexing: {
    label: 'CAPTAIN.DOCUMENTS.KNOWLEDGE_STATE.INDEXING',
    chip: 'bg-amber-500/10 text-amber-700 dark:text-amber-400',
    dot: 'bg-amber-500 animate-pulse',
  },
  not_searchable: {
    label: 'CAPTAIN.DOCUMENTS.KNOWLEDGE_STATE.NOT_SEARCHABLE',
    chip: 'bg-ruby-500/10 text-ruby-700 dark:text-ruby-400',
    dot: 'bg-ruby-500',
  },
  paused: {
    label: 'CAPTAIN.DOCUMENTS.KNOWLEDGE_STATE.PAUSED',
    chip: 'bg-n-slate-3 text-n-slate-11',
    dot: 'bg-n-slate-7',
  },
};

const exactTimestamp = useExactTimestamp();
const route = useRoute();

const { checkPermissions } = usePolicy();

const { t } = useI18n();

const [showActionsDropdown, toggleDropdown] = useToggle();
const modelValue = computed({
  get: () => props.isSelected,
  set: () => emit('select', props.id),
});

const enabledState = computed({
  get: () => props.enabled,
  set: enabled => emit('toggle', { id: props.id, enabled }),
});

const isPdf = computed(() => props.pdfDocument);
const isMarkdown = computed(() => props.markdownDocument);
const hasSafeLink = computed(() => isSafeHttpLink(props.externalLink));
const canManage = computed(() => checkPermissions(['administrator']));
const isAvailable = computed(() => props.status === 'available');
const canSync = computed(
  () => canManage.value && props.syncable && isAvailable.value
);
const isSyncing = computed(() => props.syncStatus === 'syncing');
const isFailed = computed(() => props.syncStatus === 'failed');
const isRetryableSync = computed(
  () => isFailed.value || (isSyncing.value && !props.syncInProgress)
);
const showSyncStatus = computed(() => props.syncable);
const knowledgeChip = computed(
  () => KNOWLEDGE_STATE_CHIPS[props.knowledgeState]
);
// With Dify the page text is searched directly, so a page without FAQs is normal.
const showFaqPill = computed(
  () => !isPdf.value && (!props.knowledgeState || props.responsesCount > 0)
);

const typeIcon = computed(() => {
  if (isPdf.value) return 'i-lucide-file-text';
  if (isMarkdown.value) return 'i-lucide-align-left';
  return 'i-lucide-globe';
});

const typeIconClasses = computed(() => {
  if (isPdf.value) {
    return 'bg-n-ruby-3 text-n-ruby-11 dark:bg-n-ruby-3/20';
  }
  if (isMarkdown.value) {
    return 'bg-n-teal-3 text-n-teal-11 dark:bg-n-teal-3/20';
  }
  return 'bg-n-blue-3 text-n-blue-11 dark:bg-n-blue-3/20';
});

const faqsFilteredRoute = computed(() => ({
  name: 'captain_assistants_responses_index',
  params: {
    accountId: route?.params?.accountId,
    assistantId: props.assistant?.id || route?.params?.assistantId,
  },
  query: {
    document_id: props.id,
  },
}));

const menuItems = computed(() => {
  const allOptions = [];

  if (canSync.value) {
    allOptions.push({
      label: isRetryableSync.value
        ? t('CAPTAIN.DOCUMENTS.OPTIONS.RETRY_SYNC')
        : t('CAPTAIN.DOCUMENTS.OPTIONS.SYNC_NOW'),
      value: 'sync',
      action: 'sync',
      icon: 'i-lucide-refresh-cw',
    });
  }

  if (canManage.value && !isPdf.value && !isMarkdown.value) {
    allOptions.push({
      label: t('CAPTAIN.DOCUMENTS.OPTIONS.GENERATE_FAQS'),
      value: 'generateFaqs',
      action: 'generateFaqs',
      icon: 'i-lucide-sparkles',
    });
  }

  if (canManage.value) {
    allOptions.push({
      label: t('CAPTAIN.DOCUMENTS.OPTIONS.DELETE_DOCUMENT'),
      value: 'delete',
      action: 'delete',
      icon: 'i-lucide-trash',
    });
  }

  return allOptions;
});

const createdAtLabel = computed(() => dynamicTime(props.createdAt));
const responsesCountLabel = computed(() =>
  t('CAPTAIN.DOCUMENTS.FAQ_COUNT', { n: props.responsesCount })
);
const displayLink = computed(() => {
  if (isMarkdown.value) return props.name;
  if (isPdf.value) return formatDocumentLink(props.externalLink);

  return getDocumentDisplayPath(props.externalLink);
});
const linkIcon = computed(() => {
  if (isMarkdown.value) return 'i-lucide-file-text';
  return isPdf.value ? 'i-ph-file-pdf' : 'i-ph-link-simple';
});

const handleAction = ({ action, value }) => {
  toggleDropdown(false);
  emit('action', { action, value, id: props.id });
};

const handleViewDetails = () => {
  emit('action', { action: 'viewDetails', id: props.id });
};

const handleRetry = () => {
  emit('action', { action: 'sync', id: props.id });
};
</script>

<template>
  <CardLayout
    :selectable="selectable"
    class="relative"
    :class="{ 'opacity-60': !enabled }"
    @mouseenter="emit('hover', true)"
    @mouseleave="emit('hover', false)"
  >
    <div
      v-show="showSelectionControl"
      class="absolute top-7 ltr:left-3 rtl:right-3"
    >
      <Checkbox v-model="modelValue" />
    </div>
    <div class="flex gap-3 justify-between items-center w-full">
      <div class="flex items-center gap-2.5 min-w-0 flex-1">
        <div
          class="flex items-center justify-center size-8 rounded-lg shrink-0"
          :class="typeIconClasses"
        >
          <Icon :icon="typeIcon" class="size-4" />
        </div>
        <button
          type="button"
          class="p-0 text-base text-left bg-transparent border-0 outline-transparent text-n-slate-12 line-clamp-1 underline-offset-2 hover:underline focus-visible:underline"
          @click="handleViewDetails"
        >
          {{ name }}
        </button>
        <span
          v-if="!enabled"
          class="inline-flex items-center px-1.5 py-0.5 text-xs font-medium rounded bg-n-slate-3 text-n-slate-11 shrink-0"
        >
          {{ $t('CAPTAIN.DOCUMENTS.STATUS.PAUSED') }}
        </span>
      </div>
      <div class="flex items-center gap-2 shrink-0">
        <Policy
          v-if="canManage"
          :permissions="['administrator']"
          class="flex items-center"
        >
          <Switch
            v-model="enabledState"
            :aria-label="
              enabled
                ? t('CAPTAIN.DOCUMENTS.PAUSE')
                : t('CAPTAIN.DOCUMENTS.RESUME')
            "
          />
        </Policy>
        <div
          v-if="showMenu && menuItems.length"
          v-on-clickaway="() => toggleDropdown(false)"
          class="flex relative items-center group"
        >
          <Button
            icon="i-lucide-ellipsis-vertical"
            color="slate"
            size="xs"
            class="rounded-md group-hover:bg-n-alpha-2"
            @click="toggleDropdown()"
          />
          <DropdownMenu
            v-if="showActionsDropdown"
            :menu-items="menuItems"
            class="top-full mt-1 ltr:right-0 rtl:left-0 xl:ltr:right-0 xl:rtl:left-0"
            @action="handleAction($event)"
          />
        </div>
      </div>
    </div>
    <div class="flex gap-4 justify-between items-center w-full">
      <span
        class="flex gap-1 items-center text-sm truncate shrink-0 text-n-slate-11"
      >
        <Icon icon="i-woot-captain" />
        {{ assistant?.name || '' }}
      </span>
      <a
        v-if="!isPdf && !isMarkdown && hasSafeLink"
        :href="externalLink"
        :title="externalLink"
        target="_blank"
        rel="noopener noreferrer"
        class="flex flex-1 gap-1 justify-start items-center text-sm truncate text-n-slate-11 hover:text-n-slate-12 hover:underline"
        @click.stop
      >
        <Icon :icon="linkIcon" class="shrink-0" />
        <span class="truncate">{{ displayLink }}</span>
        <Icon icon="i-lucide-external-link size-3 shrink-0 opacity-70" />
      </a>
      <span
        v-else
        class="flex flex-1 gap-1 justify-start items-center text-sm truncate text-n-slate-11"
      >
        <Icon :icon="linkIcon" class="shrink-0" />
        <span class="truncate">{{ displayLink }}</span>
      </span>
      <span
        v-if="knowledgeChip"
        v-tooltip.top="{
          content: t('CAPTAIN.DOCUMENTS.KNOWLEDGE_STATE.TOOLTIP'),
          delay: { show: 500, hide: 0 },
        }"
        class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-xs font-medium shrink-0"
        :class="knowledgeChip.chip"
      >
        <span
          data-test="chip-dot"
          class="size-1.5 rounded-full"
          :class="knowledgeChip.dot"
        />
        {{ t(knowledgeChip.label) }}
      </span>
      <router-link
        v-if="showFaqPill"
        :to="faqsFilteredRoute"
        class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-n-alpha-2 hover:bg-n-alpha-3 text-n-slate-11 hover:text-n-slate-12 transition-colors shrink-0"
        @click.stop
      >
        {{ responsesCountLabel }}
      </router-link>
      <DocumentSyncStatus
        v-if="showSyncStatus"
        :status="syncStatus"
        :last-synced-at="lastSyncedAt"
        :error-code="lastSyncErrorCode"
        :sync-in-progress="syncInProgress"
        :stale-after-hours="syncStaleAfterHours"
        :show-retry="canSync && isRetryableSync"
        @retry="handleRetry"
      />
      <div
        v-else
        v-tooltip.top="{
          content: exactTimestamp(createdAt),
          delay: { show: 500, hide: 0 },
        }"
        class="text-sm shrink-0 text-n-slate-11 line-clamp-1"
      >
        {{ createdAtLabel }}
      </div>
    </div>
  </CardLayout>
</template>

<script setup>
import { computed, ref } from 'vue';
import { useRoute } from 'vue-router';
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
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import { LIST_COLUMNS } from 'dashboard/components-next/captain/list/listColumns';
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
  // Administrators get a checkbox for bulk actions.
  selectable: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['action', 'select', 'toggle']);

const KNOWLEDGE_STATE_CHIPS = {
  searchable: {
    label: 'CAPTAIN.DOCUMENTS.KNOWLEDGE_STATE.SEARCHABLE',
    chip: 'bg-emerald-500/10 text-emerald-700 dark:text-emerald-400',
    icon: 'i-lucide-search-check',
  },
  indexing: {
    label: 'CAPTAIN.DOCUMENTS.KNOWLEDGE_STATE.INDEXING',
    chip: 'bg-amber-500/10 text-amber-700 dark:text-amber-400',
    icon: 'i-lucide-loader-circle animate-spin',
  },
  not_searchable: {
    label: 'CAPTAIN.DOCUMENTS.KNOWLEDGE_STATE.NOT_SEARCHABLE',
    chip: 'bg-ruby-500/10 text-ruby-700 dark:text-ruby-400',
    icon: 'i-lucide-search-x',
  },
  paused: {
    label: 'CAPTAIN.DOCUMENTS.KNOWLEDGE_STATE.PAUSED',
    chip: 'bg-n-slate-3 text-n-slate-11',
    icon: 'i-lucide-pause',
  },
};

const exactTimestamp = useExactTimestamp();
const timestamp = computed(() => props.lastSyncedAt || props.createdAt);
const route = useRoute();

const { checkPermissions } = usePolicy();

const { t } = useI18n();

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
const isSyncing = computed(() => props.syncStatus === 'syncing');
const isFailed = computed(() => props.syncStatus === 'failed');
const isRetryableSync = computed(
  () => isFailed.value || (isSyncing.value && !props.syncInProgress)
);
// A failed first import is not available yet but must still be retryable.
const canSync = computed(
  () =>
    canManage.value &&
    (props.syncable || isFailed.value) &&
    (isAvailable.value || isFailed.value)
);
// The row has room for one status: sync trouble wins over the knowledge state.
const showSyncStatus = computed(
  () => props.syncable && (isFailed.value || isSyncing.value)
);
const knowledgeChip = computed(
  () => KNOWLEDGE_STATE_CHIPS[props.knowledgeState]
);
// With Dify the page text is searched directly, so a page without FAQs is normal.
const showFaqPill = computed(
  () => props.responsesCount > 0 || (!isPdf.value && !props.knowledgeState)
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

const responsesCountLabel = computed(() =>
  t('CAPTAIN.DOCUMENTS.FAQ_COUNT', { n: props.responsesCount })
);
const displayLink = computed(() => {
  if (isMarkdown.value) return props.name;
  if (isPdf.value) return formatDocumentLink(props.externalLink);

  return getDocumentDisplayPath(props.externalLink);
});
const showMenu = ref(false);

const handleAction = ({ action }) => {
  showMenu.value = false;
  emit('action', { action, id: props.id });
};

const handleViewDetails = () => {
  emit('action', { action: 'viewDetails', id: props.id });
};

const handleRetry = () => {
  emit('action', { action: 'sync', id: props.id });
};
</script>

<template>
  <div
    class="group flex items-center gap-3 px-4 py-2.5 border-b border-n-weak last:border-b-0 last:rounded-b-xl transition-colors hover:bg-n-alpha-1"
    :class="{ 'bg-n-brand/5': isSelected }"
  >
    <Checkbox v-if="selectable" v-model="modelValue" :aria-label="name" />
    <div class="flex items-center flex-1 min-w-0 gap-3">
      <div
        class="flex items-center justify-center size-6 rounded shrink-0"
        :class="[typeIconClasses, { 'opacity-60': !enabled }]"
      >
        <Icon :icon="typeIcon" class="size-3.5" />
      </div>
      <button
        type="button"
        class="p-0 text-sm font-medium text-start bg-transparent border-0 outline-transparent truncate max-w-xs md:max-w-md underline-offset-2 hover:underline focus-visible:underline"
        :class="enabled ? 'text-n-slate-12' : 'text-n-slate-11'"
        @click="handleViewDetails"
      >
        {{ name }}
      </button>
      <a
        v-if="!isPdf && !isMarkdown && hasSafeLink"
        :href="externalLink"
        :title="externalLink"
        target="_blank"
        rel="noopener noreferrer"
        class="hidden sm:inline-flex min-w-0 shrink-[4] items-center gap-1 text-xs text-n-slate-10 hover:text-n-slate-12 truncate"
        @click.stop
      >
        <span class="truncate">{{ displayLink }}</span>
        <Icon icon="i-lucide-external-link size-3 shrink-0 opacity-70" />
      </a>
      <router-link
        v-if="showFaqPill"
        :to="faqsFilteredRoute"
        class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-n-alpha-2 hover:bg-n-alpha-3 text-n-slate-11 shrink-0"
        @click.stop
      >
        {{ responsesCountLabel }}
      </router-link>
    </div>
    <div class="flex items-center" :class="LIST_COLUMNS.status">
      <DocumentSyncStatus
        v-if="showSyncStatus"
        class="!text-xs"
        :status="syncStatus"
        :last-synced-at="lastSyncedAt"
        :error-code="lastSyncErrorCode"
        :sync-in-progress="syncInProgress"
        :stale-after-hours="syncStaleAfterHours"
        :show-retry="canSync && isRetryableSync"
        @retry="handleRetry"
      />
      <span
        v-else-if="!enabled"
        class="inline-flex items-center px-1.5 py-0.5 text-xs font-medium rounded-full bg-n-slate-3 text-n-slate-11"
      >
        {{ $t('KNOWLEDGE_LIST.OFF') }}
      </span>
      <span
        v-else-if="knowledgeChip"
        v-tooltip.top="{
          content: t('CAPTAIN.DOCUMENTS.KNOWLEDGE_STATE.TOOLTIP'),
          delay: { show: 500, hide: 0 },
        }"
        class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-full text-xs font-medium"
        :class="knowledgeChip.chip"
      >
        <span
          data-test="chip-dot"
          class="size-3"
          :class="knowledgeChip.icon"
          aria-hidden="true"
        />
        <span>{{ t(knowledgeChip.label) }}</span>
      </span>
    </div>
    <span
      v-tooltip.top="{
        content: exactTimestamp(timestamp),
        delay: { show: 500, hide: 0 },
      }"
      class="text-xs truncate text-n-slate-10"
      :class="LIST_COLUMNS.updated"
    >
      {{ dynamicTime(timestamp) }}
    </span>
    <div :class="LIST_COLUMNS.inUse">
      <Policy v-if="canManage" :permissions="['administrator']">
        <Switch
          v-model="enabledState"
          :aria-label="
            enabled
              ? t('CAPTAIN.DOCUMENTS.PAUSE')
              : t('CAPTAIN.DOCUMENTS.RESUME')
          "
        />
      </Policy>
    </div>
    <div
      v-on-clickaway="() => (showMenu = false)"
      class="relative"
      :class="LIST_COLUMNS.actions"
    >
      <Button
        v-if="menuItems.length"
        :aria-label="$t('KNOWLEDGE_LIST.MORE_ACTIONS')"
        icon="i-lucide-ellipsis-vertical"
        color="slate"
        variant="ghost"
        size="xs"
        @click="showMenu = !showMenu"
      />
      <DropdownMenu
        v-if="showMenu"
        :menu-items="menuItems"
        class="z-30 mt-1 top-full ltr:right-0 rtl:left-0 w-52"
        @action="handleAction"
      />
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { useExactTimestamp } from 'shared/composables/useExactTimestamp';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  status: {
    type: String,
    default: null,
  },
  lastSyncedAt: {
    type: Number,
    default: null,
  },
  errorCode: {
    type: String,
    default: null,
  },
  syncInProgress: {
    type: Boolean,
    default: false,
  },
  staleAfterHours: {
    type: Number,
    default: null,
  },
  showRetry: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['retry']);

const exactTimestamp = useExactTimestamp();

const { t } = useI18n();

const SECONDS_PER_HOUR = 3600;

const SYNCING = 'syncing';
const FAILED = 'failed';

const ERROR_CODE_LABELS = {
  not_found: 'CAPTAIN.DOCUMENTS.SYNC_ERRORS.NOT_FOUND',
  access_denied: 'CAPTAIN.DOCUMENTS.SYNC_ERRORS.ACCESS_DENIED',
  timeout: 'CAPTAIN.DOCUMENTS.SYNC_ERRORS.TIMEOUT',
  content_empty: 'CAPTAIN.DOCUMENTS.SYNC_ERRORS.CONTENT_EMPTY',
  fetch_failed: 'CAPTAIN.DOCUMENTS.SYNC_ERRORS.FETCH_FAILED',
  sync_error: 'CAPTAIN.DOCUMENTS.SYNC_ERRORS.SYNC_ERROR',
  rendering_required: 'CAPTAIN.DOCUMENTS.SYNC_ERRORS.RENDERING_REQUIRED',
  robots_disallowed: 'CAPTAIN.DOCUMENTS.SYNC_ERRORS.ROBOTS_DISALLOWED',
  thin_content: 'CAPTAIN.DOCUMENTS.SYNC_ERRORS.THIN_CONTENT',
  duplicate_content: 'CAPTAIN.DOCUMENTS.SYNC_ERRORS.DUPLICATE_CONTENT',
  dify_indexing_timeout: 'CAPTAIN.DOCUMENTS.SYNC_ERRORS.INDEXING_TIMEOUT',
  dify_indexing_failed: 'CAPTAIN.DOCUMENTS.SYNC_ERRORS.INDEXING_FAILED',
  dify_document_unavailable: 'CAPTAIN.DOCUMENTS.SYNC_ERRORS.INDEXING_FAILED',
  dify_not_configured: 'CAPTAIN.DOCUMENTS.SYNC_ERRORS.KNOWLEDGE_NOT_CONFIGURED',
};
// Other Dify failures (HTTP status codes, dataset setup) share one message.
const DIFY_ERROR_PREFIX = 'dify_';
const DIFY_ERROR_LABEL = 'CAPTAIN.DOCUMENTS.SYNC_ERRORS.KNOWLEDGE_BASE_ERROR';
const DEFAULT_ERROR_LABEL = 'CAPTAIN.DOCUMENTS.SYNC_ERRORS.DEFAULT';

const hasSyncingStatus = computed(() => props.status === SYNCING);
const isSyncing = computed(
  () => hasSyncingStatus.value && props.syncInProgress
);
const isStaleSync = computed(
  () => hasSyncingStatus.value && !props.syncInProgress
);
const isFailed = computed(() => props.status === FAILED);
const canRetry = computed(() => isFailed.value || isStaleSync.value);
const hasBeenSynced = computed(() => Boolean(props.lastSyncedAt));

const ageInHours = computed(() => {
  if (!props.lastSyncedAt) return null;
  const nowSeconds = Date.now() / 1000;
  return (nowSeconds - props.lastSyncedAt) / SECONDS_PER_HOUR;
});

const staleAfterHours = computed(() => Number(props.staleAfterHours));
const hasStaleThreshold = computed(
  () => Number.isFinite(staleAfterHours.value) && staleAfterHours.value > 0
);
const isStale = computed(
  () =>
    hasStaleThreshold.value &&
    ageInHours.value !== null &&
    ageInHours.value >= staleAfterHours.value
);

const errorLabel = computed(() => {
  if (ERROR_CODE_LABELS[props.errorCode]) {
    return t(ERROR_CODE_LABELS[props.errorCode]);
  }
  if (props.errorCode?.startsWith(DIFY_ERROR_PREFIX)) {
    return t(DIFY_ERROR_LABEL);
  }
  return t(DEFAULT_ERROR_LABEL);
});

const label = computed(() => {
  if (isSyncing.value) return t('CAPTAIN.DOCUMENTS.SYNC_STATUS.SYNCING');
  if (isStaleSync.value) return t('CAPTAIN.DOCUMENTS.SYNC_STATUS.STALE_SYNC');
  if (isFailed.value) return t('CAPTAIN.DOCUMENTS.SYNC_STATUS.FAILED');
  if (hasBeenSynced.value)
    return t('CAPTAIN.DOCUMENTS.SYNC_STATUS.SYNCED', {
      time: dynamicTime(props.lastSyncedAt),
    });
  return t('CAPTAIN.DOCUMENTS.SYNC_STATUS.NEVER_SYNCED');
});

const fullLabel = computed(() => {
  if (isSyncing.value) return t('CAPTAIN.DOCUMENTS.SYNC_STATUS.SYNCING');
  if (isStaleSync.value) return t('CAPTAIN.DOCUMENTS.SYNC_STATUS.STALE_SYNC');
  if (isFailed.value)
    return t('CAPTAIN.DOCUMENTS.SYNC_STATUS.FAILED_REASON', {
      error: errorLabel.value,
    });
  if (hasBeenSynced.value)
    return t('CAPTAIN.DOCUMENTS.SYNC_STATUS.SYNCED', {
      time: exactTimestamp(props.lastSyncedAt),
    });
  return t('CAPTAIN.DOCUMENTS.SYNC_STATUS.NEVER_SYNCED');
});

const tone = computed(() => {
  if (isSyncing.value) return 'amber';
  if (isStaleSync.value) return 'amber';
  if (isFailed.value) return 'ruby';
  if (isStale.value) return 'amber';
  return 'slate';
});

const textClass = computed(() => {
  if (tone.value === 'amber') return 'text-n-amber-11';
  if (tone.value === 'ruby') return 'text-n-ruby-11';
  return 'text-n-slate-11';
});

const statusIcon = computed(() => {
  if (isFailed.value || isStale.value || isStaleSync.value) {
    return 'i-lucide-circle-alert';
  }
  return 'i-lucide-refresh-cw';
});
</script>

<template>
  <span
    v-tooltip.top="{ content: fullLabel, delay: { show: 500, hide: 0 } }"
    class="flex gap-1.5 items-center text-sm truncate shrink-0 tabular-nums"
    :class="textClass"
  >
    <Spinner v-if="isSyncing" class="text-n-amber-11 size-3" />
    <Icon v-else :icon="statusIcon" class="shrink-0 size-3.5" />
    <span class="truncate">{{ label }}</span>
    <Button
      v-if="showRetry && canRetry"
      :label="t('CAPTAIN.DOCUMENTS.OPTIONS.RETRY_SYNC')"
      xs
      link
      ruby
      icon="i-lucide-refresh-cw"
      class="hover:!no-underline !gap-1 ms-1"
      @click.stop="emit('retry')"
    />
  </span>
</template>

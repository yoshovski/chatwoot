<script setup>
import { computed, onMounted, onUnmounted, ref, nextTick, watch } from 'vue';
import { useTimeoutPoll } from '@vueuse/core';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useRoute } from 'vue-router';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { debounce } from '@chatwoot/utils';

import DeleteDialog from 'dashboard/components-next/captain/pageComponents/DeleteDialog.vue';
import WebsitePagesDialog from 'dashboard/components-next/captain/knowledge/WebsitePagesDialog.vue';
import KnowledgeSourceBrowser from 'dashboard/components-next/captain/knowledge/KnowledgeSourceBrowser.vue';
import DocumentCard from 'dashboard/components-next/captain/assistant/DocumentCard.vue';
import DocumentFilter from 'dashboard/components-next/captain/assistant/DocumentFilter.vue';
import KnowledgeBulkActions from 'dashboard/components-next/captain/list/KnowledgeBulkActions.vue';
import ListHeader from 'dashboard/components-next/captain/list/ListHeader.vue';
import { useListSelection } from 'dashboard/components-next/captain/list/useListSelection';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'next/button/Button.vue';
import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import TestAgentButton from 'dashboard/components-next/captain/TestAgentButton.vue';
import CaptainPaywall from 'dashboard/components-next/captain/pageComponents/Paywall.vue';
import DocumentDetails from 'dashboard/components-next/captain/pageComponents/document/DocumentDetails.vue';
import CreateDocumentDialog from 'dashboard/components-next/captain/pageComponents/document/CreateDocumentDialog.vue';
import DocumentPageEmptyState from 'dashboard/components-next/captain/pageComponents/emptyStates/DocumentPageEmptyState.vue';
import FeatureSpotlightPopover from 'dashboard/components-next/feature-spotlight/FeatureSpotlightPopover.vue';
import LimitBanner from 'dashboard/components-next/captain/pageComponents/document/LimitBanner.vue';
import CaptainDocumentAPI from 'dashboard/api/captain/document';
import shopifyAPI from 'dashboard/api/integrations/shopify';
import { useI18n } from 'vue-i18n';

const route = useRoute();
const store = useStore();
const { t } = useI18n();
const { checkPermissions } = usePolicy();

const SYNC_POLL_INTERVAL_MS = 5000;
const SYNC_POLL_MAX_DURATION_MS = 15 * 60 * 1000;

const { isOnChatwootCloud, currentAccount } = useAccount();
const uiFlags = useMapGetter('captainDocuments/getUIFlags');
const documents = useMapGetter('captainDocuments/getRecords');
const isFetching = computed(() => uiFlags.value.fetchingList);
const documentsMeta = useMapGetter('captainDocuments/getMeta');

const selectedAssistantId = computed(() => Number(route.params.assistantId));
const websitePagesDialog = ref(null);
const canManageDocuments = computed(() => checkPermissions(['administrator']));

const selectedDocument = ref(null);
const deleteDocumentDialog = ref(null);

const handleDelete = () => {
  deleteDocumentDialog.value.dialogRef.open();
};

const showDocumentDetails = ref(false);
const showCreateDialog = ref(false);
const createDocumentDialog = ref(null);

const handleShowDocumentDetails = () => {
  showDocumentDetails.value = true;
};
const handleCreateDocument = () => {
  showCreateDialog.value = true;
  nextTick(() => createDocumentDialog.value.dialogRef.open());
};

const handleDocumentDetailsClose = () => {
  showDocumentDetails.value = false;
};

const handleCreateDialogClose = () => {
  showCreateDialog.value = false;
};

const documentFilter = ref(null);
const syncIntervalHours = ref(null);
const searchQuery = ref('');
// 'all', 'pdf', 'text', or a website host.
const sourceFilter = ref('all');
const documentSectionsPanel = ref(null);

const currentAssistantId = () =>
  Number.isFinite(selectedAssistantId.value) ? selectedAssistantId.value : null;

const buildDocumentFilterParams = (page = 1) => {
  const filterParams = documentFilter.value?.buildParams(page) ?? {
    page,
    sort: 'recently_updated',
  };
  const assistantId = currentAssistantId();
  if (assistantId) filterParams.assistantId = assistantId;
  const trimmedQuery = searchQuery.value.trim();
  if (trimmedQuery) filterParams.searchKey = trimmedQuery;
  if (['pdf', 'text'].includes(sourceFilter.value)) {
    filterParams.source = sourceFilter.value;
  } else if (assistantId && sourceFilter.value !== 'all') {
    filterParams.website = sourceFilter.value;
  }
  return filterParams;
};

// The same filters in the API's own names, for bulk actions on all matching sources.
const bulkFilters = () => {
  const { assistantId, searchKey, filter, source, website } =
    buildDocumentFilterParams();
  return {
    assistant_id: assistantId,
    search_key: searchKey,
    filter,
    source,
    website,
  };
};

const selection = useListSelection({
  items: documents,
  total: computed(() => documentsMeta.value?.totalCount || 0),
  filters: bulkFilters,
});

let documentsRequestId = 0;
let fetchingListRequestId = null;

const isCurrentDocumentRequest = (requestId, filterParams) =>
  requestId === documentsRequestId &&
  (filterParams.assistantId || null) === currentAssistantId();

const fetchDocuments = async (page = 1, { showLoader = true } = {}) => {
  documentsRequestId += 1;
  const requestId = documentsRequestId;
  const filterParams = buildDocumentFilterParams(page);

  if (showLoader) {
    fetchingListRequestId = requestId;
    store.dispatch('captainDocuments/setFetchingList', true);
  }

  try {
    const response = await CaptainDocumentAPI.get(filterParams);

    if (!isCurrentDocumentRequest(requestId, filterParams)) {
      return [];
    }

    const { payload, meta } = response.data;
    store.dispatch('captainDocuments/setRecords', { records: payload, meta });
    syncIntervalHours.value = Number(meta?.sync_interval_hours) || null;
    return payload;
  } catch (error) {
    if (isCurrentDocumentRequest(requestId, filterParams)) {
      throw error;
    }
    return [];
  } finally {
    if (showLoader && fetchingListRequestId === requestId) {
      fetchingListRequestId = null;
      store.dispatch('captainDocuments/setFetchingList', false);
    }
  }
};

const refreshDocumentsPage = (
  page = documentsMeta.value?.page || 1,
  { showLoader = false } = {}
) => {
  return fetchDocuments(page, { showLoader }).catch(() => {});
};

const onFiltersChanged = () => {
  selection.clear();
  fetchDocuments(1);
};

const debouncedSearch = debounce(onFiltersChanged, 300);

const syncPollStartedAt = ref(null);

const hasDocumentsSyncing = computed(() =>
  (documents.value || []).some(doc => doc.sync_in_progress)
);

const hasSyncingDocuments = computed(() => hasDocumentsSyncing.value);

const isWithinSyncPollWindow = () =>
  syncPollStartedAt.value &&
  Date.now() - syncPollStartedAt.value < SYNC_POLL_MAX_DURATION_MS;

const shouldContinueSyncPolling = () =>
  hasSyncingDocuments.value && isWithinSyncPollWindow();

let syncPollingControls;

function stopSyncPolling() {
  syncPollingControls.pause();
  syncPollStartedAt.value = null;
}

async function pollSyncDocuments() {
  try {
    await refreshDocumentsPage();
  } catch (error) {
    // Keep the existing polling decision based on the last known sync state.
  }

  if (!shouldContinueSyncPolling()) {
    stopSyncPolling();
  }
}

function scheduleSyncPoll({ extendWindow = false } = {}) {
  if (extendWindow || !syncPollStartedAt.value) {
    syncPollStartedAt.value = Date.now();
  }

  if (syncPollingControls.isActive.value) return;
  syncPollingControls.resume();
}

syncPollingControls = useTimeoutPoll(pollSyncDocuments, SYNC_POLL_INTERVAL_MS, {
  immediate: false,
});

watch(hasSyncingDocuments, isSyncing => {
  if (isSyncing) {
    scheduleSyncPoll();
  }
});

const handleSync = async id => {
  try {
    await store.dispatch('captainDocuments/sync', id);
    useAlert(t('CAPTAIN.DOCUMENTS.SYNC.QUEUED_MESSAGE'));
    scheduleSyncPoll({ extendWindow: true });
  } catch (error) {
    useAlert(t('CAPTAIN.DOCUMENTS.SYNC.ERROR_MESSAGE'));
  }
};

const handleToggleDocument = async ({ id, enabled }) => {
  try {
    await store.dispatch('captainDocuments/update', { id, enabled });
  } catch {
    useAlert(t('CAPTAIN.DOCUMENTS.TOGGLE_ERROR'));
  }
};

const handleGenerateFaqs = async id => {
  try {
    await CaptainDocumentAPI.generateFaqs(id);
    useAlert(t('CAPTAIN.DOCUMENTS.GENERATE_FAQS.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(
      error?.response?.data?.error ||
        t('CAPTAIN.DOCUMENTS.GENERATE_FAQS.ERROR_MESSAGE')
    );
  }
};

const handleAction = ({ action, id }) => {
  selectedDocument.value = documents.value.find(
    captainDocument => id === captainDocument.id
  );

  nextTick(() => {
    if (action === 'delete') {
      handleDelete();
    } else if (action === 'viewDetails') {
      handleShowDocumentDetails();
    } else if (action === 'sync') {
      handleSync(id);
    } else if (action === 'generateFaqs') {
      handleGenerateFaqs(id);
    }
  });
};

const onPageChange = page => {
  selection.clear();
  fetchDocuments(page);
};

const onDeleteSuccess = () => {
  if (documents.value?.length === 0 && documentsMeta.value?.page > 1) {
    onPageChange(documentsMeta.value.page - 1);
  } else {
    refreshDocumentsPage();
  }
};

const fetchDocumentsAfterBulkDelete = () => {
  const currentPage = documentsMeta.value?.page || 1;
  const hasNoDocumentsLeft = documents.value?.length === 0;
  fetchDocuments(hasNoDocumentsLeft && currentPage > 1 ? currentPage - 1 : 1);
  documentSectionsPanel.value?.load();
};

const onCreateSuccess = () => {
  refreshDocumentsPage(1);
  documentSectionsPanel.value?.load();
};

const isFileSource = computed(() =>
  ['pdf', 'text'].includes(sourceFilter.value)
);

const clearFilters = () => {
  documentFilter.value?.reset();
  searchQuery.value = '';
  sourceFilter.value = 'all';
  onFiltersChanged();
};

watch(sourceFilter, onFiltersChanged);

const hasActiveDocumentFilters = computed(
  () =>
    (documentFilter.value?.hasActiveFilters ?? false) ||
    Boolean(searchQuery.value.trim()) ||
    sourceFilter.value !== 'all'
);

const shopifyHook = ref(null);

// Hosts of the connected Shopify store, without "www.", for the add-document form's defaults.
const shopifyStoreHosts = computed(() => {
  const hook = shopifyHook.value;
  if (hook?.state !== 'connected') return [];
  return [
    hook.shop_domain && `https://${hook.shop_domain}`,
    hook.storefront_url,
  ]
    .filter(Boolean)
    .flatMap(url => {
      try {
        return [new URL(url).hostname.toLowerCase().replace(/^www\./, '')];
      } catch {
        return [];
      }
    });
});

const fetchShopifyStatus = async () => {
  if (!currentAccount.value?.features?.shopify_integration) return;
  try {
    const { data } = await shopifyAPI.getStatus();
    shopifyHook.value = data.hook || data;
  } catch {
    shopifyHook.value = null;
  }
};

onMounted(() => {
  fetchShopifyStatus();
});

watch(
  selectedAssistantId,
  async () => {
    documentFilter.value?.reset();
    searchQuery.value = '';
    sourceFilter.value = 'all';
    selection.clear();
    syncIntervalHours.value = null;
    stopSyncPolling();
    await fetchDocuments(1);
    if (hasSyncingDocuments.value) scheduleSyncPoll();
  },
  { immediate: true }
);

onUnmounted(() => {
  stopSyncPolling();
  documentsRequestId += 1;
});
</script>

<template>
  <PageLayout
    :header-title="$t('PLATFORM_NAV.DATA_SOURCES')"
    :button-label="$t('CAPTAIN.DOCUMENTS.ADD_NEW')"
    :button-policy="['administrator']"
    :total-count="documentsMeta.totalCount"
    :current-page="documentsMeta.page"
    :show-pagination-footer="!isFetching && !!documents.length"
    :is-fetching="isFetching"
    :is-empty="!documents.length && !hasActiveDocumentFilters"
    :feature-flag="FEATURE_FLAGS.CAPTAIN"
    @update:current-page="onPageChange"
    @click="handleCreateDocument"
  >
    <template #headerActions>
      <TestAgentButton :assistant-id="selectedAssistantId" />
    </template>
    <template #knowMore>
      <FeatureSpotlightPopover
        :button-label="$t('CAPTAIN.HEADER_KNOW_MORE')"
        :title="$t('CAPTAIN.DOCUMENTS.EMPTY_STATE.FEATURE_SPOTLIGHT.TITLE')"
        :note="$t('CAPTAIN.DOCUMENTS.EMPTY_STATE.FEATURE_SPOTLIGHT.NOTE')"
        :hide-actions="!isOnChatwootCloud"
        fallback-thumbnail="/assets/images/dashboard/captain/document-popover-light.svg"
        fallback-thumbnail-dark="/assets/images/dashboard/captain/document-popover-dark.svg"
        learn-more-url="https://chwt.app/captain-document"
      />
    </template>

    <template #emptyState>
      <DocumentPageEmptyState @click="handleCreateDocument" />
    </template>

    <template #paywall>
      <CaptainPaywall />
    </template>

    <template #controls>
      <KnowledgeSourceBrowser
        v-if="selectedAssistantId > 0"
        ref="documentSectionsPanel"
        v-model:source="sourceFilter"
        :assistant-id="selectedAssistantId"
        :can-manage="canManageDocuments"
        @manage="websitePagesDialog.open($event)"
      >
        <Input
          v-model="searchQuery"
          :placeholder="$t('CAPTAIN.DOCUMENTS.FILTERS.SEARCH_PLACEHOLDER')"
          class="max-w-64 min-w-0 w-full"
          size="sm"
          type="search"
          @input="debouncedSearch"
        />
        <template #filters>
          <DocumentFilter
            ref="documentFilter"
            :show-status="!isFileSource"
            @change="onFiltersChanged"
          />
        </template>
      </KnowledgeSourceBrowser>
    </template>

    <template #body>
      <LimitBanner class="mb-5" />

      <div
        v-if="!documents.length && hasActiveDocumentFilters"
        class="flex flex-col items-center justify-center min-h-80 gap-2 text-center"
      >
        <span class="text-base font-medium text-n-slate-12">
          {{ $t('CAPTAIN.DOCUMENTS.EMPTY_STATE.FILTERED_TITLE') }}
        </span>
        <span class="max-w-md text-sm text-n-slate-11">
          {{ $t('CAPTAIN.DOCUMENTS.EMPTY_STATE.FILTERED_SUBTITLE') }}
        </span>
        <Button
          :label="$t('PLATFORM_NAV.CLEAR_FILTERS')"
          size="sm"
          variant="link"
          @click="clearFilters"
        />
      </div>

      <template v-else>
        <section
          :aria-label="$t('PLATFORM_NAV.DATA_SOURCES')"
          class="border rounded-xl border-n-weak bg-n-solid-1"
        >
          <ListHeader
            :selection="selection"
            :selectable="canManageDocuments"
            :label="$t('KNOWLEDGE_LIST.COLUMNS.NAME')"
            :columns="['status', 'updated', 'inUse', 'actions']"
          >
            <Button
              v-if="hasActiveDocumentFilters"
              :label="$t('PLATFORM_NAV.CLEAR_FILTERS')"
              size="xs"
              variant="link"
              @click="clearFilters"
            />
          </ListHeader>
          <DocumentCard
            v-for="doc in documents"
            :id="doc.id"
            :key="doc.id"
            :name="doc.name || doc.external_link"
            :external-link="doc.external_link"
            :pdf-document="doc.pdf_document"
            :markdown-document="doc.markdown_document"
            :syncable="doc.syncable"
            :assistant="doc.assistant"
            :created-at="doc.created_at"
            :status="doc.status"
            :enabled="doc.enabled !== false"
            :sync-status="doc.sync_status"
            :last-synced-at="doc.last_synced_at"
            :last-sync-error-code="doc.last_sync_error_code"
            :sync-in-progress="doc.sync_in_progress"
            :sync-stale-after-hours="syncIntervalHours"
            :responses-count="doc.responses_count"
            :knowledge-state="doc.knowledge_state"
            :selectable="canManageDocuments"
            :is-selected="selection.isSelected(doc.id)"
            @action="handleAction"
            @select="selection.toggle"
            @toggle="handleToggleDocument"
          />
        </section>
        <KnowledgeBulkActions
          v-if="canManageDocuments"
          type="AssistantDocument"
          :selection="selection"
          :total="documentsMeta.totalCount || 0"
          @updated="refreshDocumentsPage()"
          @deleted="fetchDocumentsAfterBulkDelete"
          @sync-queued="scheduleSyncPoll({ extendWindow: true })"
        />
      </template>
    </template>

    <DocumentDetails
      v-if="showDocumentDetails"
      :captain-document="selectedDocument"
      @close="handleDocumentDetailsClose"
    />
    <CreateDocumentDialog
      v-if="showCreateDialog"
      ref="createDocumentDialog"
      :assistant-id="selectedAssistantId"
      :store-hosts="shopifyStoreHosts"
      @create-success="onCreateSuccess"
      @close="handleCreateDialogClose"
    />
    <WebsitePagesDialog
      v-if="canManageDocuments && selectedAssistantId > 0"
      ref="websitePagesDialog"
      :assistant-id="selectedAssistantId"
      @saved="onCreateSuccess"
    />
    <DeleteDialog
      v-if="selectedDocument"
      ref="deleteDocumentDialog"
      :entity="selectedDocument"
      type="Documents"
      @delete-success="onDeleteSuccess"
    />
  </PageLayout>
</template>

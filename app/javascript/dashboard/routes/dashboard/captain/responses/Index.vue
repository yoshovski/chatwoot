<script setup>
import { computed, onUnmounted, ref, nextTick, watch } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { debounce } from '@chatwoot/utils';
import { useAccount } from 'dashboard/composables/useAccount';
import CaptainResponseAPI from 'dashboard/api/captain/response';

import Banner from 'dashboard/components-next/banner/Banner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import KnowledgeHeader from 'dashboard/components-next/captain/knowledge/KnowledgeHeader.vue';
import BulkSelectBar from 'dashboard/components-next/captain/assistant/BulkSelectBar.vue';
import DeleteDialog from 'dashboard/components-next/captain/pageComponents/DeleteDialog.vue';
import BulkDeleteDialog from 'dashboard/components-next/captain/pageComponents/BulkDeleteDialog.vue';
import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import CaptainPaywall from 'dashboard/components-next/captain/pageComponents/Paywall.vue';
import ResponseCard from 'dashboard/components-next/captain/assistant/ResponseCard.vue';
import CreateResponseDialog from 'dashboard/components-next/captain/pageComponents/response/CreateResponseDialog.vue';
import ResponsePageEmptyState from 'dashboard/components-next/captain/pageComponents/emptyStates/ResponsePageEmptyState.vue';
import FeatureSpotlightPopover from 'dashboard/components-next/feature-spotlight/FeatureSpotlightPopover.vue';
import LimitBanner from 'dashboard/components-next/captain/pageComponents/response/LimitBanner.vue';
import ConversationUsageDrawer from 'dashboard/components-next/captain/pageComponents/ConversationUsageDrawer.vue';

const router = useRouter();
const route = useRoute();
const store = useStore();
const { isOnChatwootCloud } = useAccount();
const uiFlags = useMapGetter('captainResponses/getUIFlags');
const responseMeta = useMapGetter('captainResponses/getMeta');
const responses = useMapGetter('captainResponses/getRecords');
const isFetching = computed(() => uiFlags.value.fetchingList);

const selectedResponse = ref(null);
const usageResponse = ref(null);
const showResponseUsage = ref(false);
const deleteDialog = ref(null);
const bulkDeleteDialog = ref(null);

const documentIdFilter = ref(
  route.query.document_id ? Number(route.query.document_id) : null
);
const sourceTypeFilter = ref(route.query.source_type || null);
const openSourceMenu = ref(false);

const dialogType = ref('');
const searchQuery = ref('');
const { t } = useI18n();

const createDialog = ref(null);

const selectedAssistantId = computed(() => Number(route.params.assistantId));

const suggestionCount = useMapGetter('captainFaqSuggestions/getOpenCount');

const handleDelete = () => {
  deleteDialog.value.dialogRef.open();
};

const handleCreate = () => {
  dialogType.value = 'create';
  nextTick(() => createDialog.value.dialogRef.open());
};

const handleEdit = () => {
  dialogType.value = 'edit';
  nextTick(() => createDialog.value.dialogRef.open());
};

const handleAction = ({ action, id }) => {
  selectedResponse.value = responses.value.find(response => id === response.id);
  nextTick(() => {
    if (action === 'delete') {
      handleDelete();
    }
    if (action === 'edit') {
      handleEdit();
    }
  });
};

const handleNavigationAction = ({ id, type }) => {
  if (type === 'Conversation') {
    router.push({
      name: 'inbox_conversation',
      params: { conversation_id: id },
    });
  }
};

const handleCreateClose = () => {
  dialogType.value = '';
  selectedResponse.value = null;
};

const handleShowResponseUsage = id => {
  usageResponse.value =
    responses.value.find(response => response.id === id) || null;
  showResponseUsage.value = Boolean(usageResponse.value);
};

const handleResponseUsageClose = () => {
  showResponseUsage.value = false;
};

const sourceOptions = computed(() => [
  {
    label: t('CAPTAIN.RESPONSES.FILTERS.SOURCE.ALL'),
    value: null,
  },
  {
    label: t('CAPTAIN.RESPONSES.FILTERS.SOURCE.HAND_TYPED'),
    value: 'User',
  },
  {
    label: t('CAPTAIN.RESPONSES.FILTERS.SOURCE.CONVERSATION'),
    value: 'Conversation',
  },
]);

const currentSourceLabel = computed(() => {
  const match = sourceOptions.value.find(
    opt => opt.value === sourceTypeFilter.value
  );
  return match ? match.label : t('CAPTAIN.RESPONSES.FILTERS.SOURCE.ALL');
});

const activeDocumentName = computed(() => {
  if (!documentIdFilter.value) return '';
  const docResponse = responses.value.find(
    r =>
      r.documentable?.type === 'Captain::Document' &&
      r.documentable?.id === documentIdFilter.value
  );
  if (docResponse?.documentable?.name) {
    return docResponse.documentable.name;
  }
  const storeDoc = store.getters['captainDocuments/getRecord']?.(
    documentIdFilter.value
  );
  if (storeDoc?.name) return storeDoc.name;

  return `#${documentIdFilter.value}`;
});

const handleToggleResponse = async ({ id, enabled }) => {
  try {
    await store.dispatch('captainResponses/update', { id, enabled });
  } catch {
    useAlert(t('CAPTAIN.RESPONSES.TOGGLE_ERROR'));
  }
};

const fetchResponseUsage = ({ resourceId, ...params }) =>
  CaptainResponseAPI.getDrilldown({ responseId: resourceId, ...params });

const updateURLWithFilters = (page, search, docId, sourceType) => {
  const query = {
    page: page || 1,
  };

  if (search) {
    query.search = search;
  }
  if (docId) {
    query.document_id = docId;
  }
  if (sourceType) {
    query.source_type = sourceType;
  }

  router.replace({ query });
};

const { run: runListRequest, abort: abortListRequest } = useAbortableRequest();

const fetchResponses = async (page = 1) => {
  const filterParams = { page };

  if (selectedAssistantId.value) {
    filterParams.assistantId = selectedAssistantId.value;
  }
  if (searchQuery.value) {
    filterParams.search = searchQuery.value;
  }
  if (documentIdFilter.value) {
    filterParams.documentId = documentIdFilter.value;
  }
  if (sourceTypeFilter.value) {
    filterParams.documentableType = sourceTypeFilter.value;
  }

  // Update URL with current filters
  updateURLWithFilters(
    page,
    searchQuery.value,
    documentIdFilter.value,
    sourceTypeFilter.value
  );

  store.dispatch('captainResponses/setFetchingList', true);

  try {
    const response = await runListRequest(signal =>
      CaptainResponseAPI.get({ ...filterParams, signal })
    );

    if (!response) return;

    store.dispatch('captainResponses/setRecords', {
      records: response.data.payload,
      meta: response.data.meta,
    });
    store.dispatch('captainResponses/setFetchingList', false);
  } catch (error) {
    useAlert(error?.message || t('CAPTAIN.RESPONSES.ERRORS.LOAD'));
    store.dispatch('captainResponses/setFetchingList', false);
  }
};

const handleSourceSelect = ({ value }) => {
  openSourceMenu.value = false;
  sourceTypeFilter.value = value;
  documentIdFilter.value = null;
  fetchResponses(1);
};

const clearDocumentFilter = () => {
  documentIdFilter.value = null;
  fetchResponses(1);
};

// Bulk action
const bulkSelectedIds = ref(new Set());
const hoveredCard = ref(null);

const buildSelectedCountLabel = computed(() => {
  const count = responses.value?.length || 0;
  const isAllSelected = bulkSelectedIds.value.size === count && count > 0;
  return isAllSelected
    ? t('CAPTAIN.RESPONSES.UNSELECT_ALL', { count })
    : t('CAPTAIN.RESPONSES.SELECT_ALL', { count });
});

const selectedCountLabel = computed(() => {
  return t('CAPTAIN.RESPONSES.SELECTED', {
    count: bulkSelectedIds.value.size,
  });
});

const handleCardHover = (isHovered, id) => {
  hoveredCard.value = isHovered ? id : null;
};

const handleCardSelect = id => {
  const selected = new Set(bulkSelectedIds.value);
  selected[selected.has(id) ? 'delete' : 'add'](id);
  bulkSelectedIds.value = selected;
};

const fetchResponseAfterBulkAction = () => {
  const hasNoResponsesLeft = responses.value?.length === 0;
  const currentPage = responseMeta.value?.page;

  if (hasNoResponsesLeft) {
    // Page is now empty after bulk action.
    // Fetch the previous page if not already on the first page.
    const pageToFetch = currentPage > 1 ? currentPage - 1 : currentPage;
    fetchResponses(pageToFetch);
  } else {
    // Page still has responses left, re-fetch the same page.
    fetchResponses(currentPage);
  }

  // Clear selection
  bulkSelectedIds.value = new Set();
};

const onPageChange = page => {
  const hadSelection = bulkSelectedIds.value.size > 0;

  showResponseUsage.value = false;
  usageResponse.value = null;

  fetchResponses(page);

  if (hadSelection) {
    bulkSelectedIds.value = new Set();
  }
};

const onDeleteSuccess = () => {
  if (responses.value?.length === 0 && responseMeta.value?.page > 1) {
    onPageChange(responseMeta.value.page - 1);
  }
};

const onBulkDeleteSuccess = () => {
  fetchResponseAfterBulkAction();
};

const debouncedSearch = debounce(async () => {
  fetchResponses(1);
}, 500);

const handleSearchInput = () => {
  abortListRequest();
  debouncedSearch();
};

const initializeFromURL = () => {
  searchQuery.value = route.query.search || '';
  documentIdFilter.value = route.query.document_id
    ? Number(route.query.document_id)
    : null;
  sourceTypeFilter.value = route.query.source_type || null;
  const pageFromURL = parseInt(route.query.page, 10) || 1;
  fetchResponses(pageFromURL);
};

watch(
  () => route.query.document_id,
  newDocId => {
    const parsedId = newDocId ? Number(newDocId) : null;
    if (parsedId !== documentIdFilter.value) {
      documentIdFilter.value = parsedId;
      fetchResponses(1);
    }
  }
);

const navigateToFaqSuggestions = () => {
  router.push({
    name: 'captain_assistants_faq_suggestions',
    params: {
      accountId: route.params.accountId,
      assistantId: selectedAssistantId.value,
    },
  });
};

watch(
  selectedAssistantId,
  () => {
    selectedResponse.value = null;
    usageResponse.value = null;
    showResponseUsage.value = false;
    bulkSelectedIds.value = new Set();
    store.dispatch('captainResponses/setRecords', {
      records: [],
      meta: { page: 1, total_count: 0 },
    });
    initializeFromURL();
    store.dispatch(
      'captainFaqSuggestions/fetchOpenCount',
      selectedAssistantId.value
    );
  },
  { immediate: true }
);

onUnmounted(() => {
  store.dispatch('captainResponses/setFetchingList', false);
});
</script>

<template>
  <PageLayout
    :total-count="responseMeta.totalCount"
    :current-page="responseMeta.page"
    :button-policy="['administrator']"
    :header-title="$t('CAPTAIN.RESPONSES.HEADER')"
    :button-label="$t('CAPTAIN.RESPONSES.ADD_NEW')"
    :is-fetching="isFetching"
    :is-empty="!responses.length"
    :show-pagination-footer="!isFetching && !!responses.length"
    :feature-flag="FEATURE_FLAGS.CAPTAIN"
    @update:current-page="onPageChange"
    @click="handleCreate"
  >
    <template #knowMore>
      <FeatureSpotlightPopover
        :button-label="$t('CAPTAIN.HEADER_KNOW_MORE')"
        :title="$t('CAPTAIN.RESPONSES.EMPTY_STATE.FEATURE_SPOTLIGHT.TITLE')"
        :note="$t('CAPTAIN.RESPONSES.EMPTY_STATE.FEATURE_SPOTLIGHT.NOTE')"
        :hide-actions="!isOnChatwootCloud"
        fallback-thumbnail="/assets/images/dashboard/captain/faqs-popover-light.svg"
        fallback-thumbnail-dark="/assets/images/dashboard/captain/faqs-popover-dark.svg"
        learn-more-url="https://chwt.app/captain-faq"
      />
    </template>

    <template #search>
      <div
        v-if="bulkSelectedIds.size === 0"
        class="flex gap-3 justify-between w-full items-center"
      >
        <Input
          v-model="searchQuery"
          :placeholder="$t('CAPTAIN.RESPONSES.SEARCH_PLACEHOLDER')"
          class="w-64"
          size="sm"
          type="search"
          autofocus
          @input="handleSearchInput"
        />
      </div>
    </template>

    <template #controls>
      <KnowledgeHeader />
    </template>

    <template #subHeader>
      <BulkSelectBar
        v-if="bulkSelectedIds.size > 0"
        v-model="bulkSelectedIds"
        :all-items="responses"
        :select-all-label="buildSelectedCountLabel"
        :selected-count-label="selectedCountLabel"
        :delete-label="$t('CAPTAIN.RESPONSES.BULK_DELETE_BUTTON')"
        class="w-fit mb-2"
        @bulk-delete="bulkDeleteDialog.dialogRef.open()"
      />
      <div v-else class="flex flex-wrap items-center gap-2 mb-3">
        <div v-on-clickaway="() => (openSourceMenu = false)" class="relative">
          <Button
            :label="currentSourceLabel"
            icon="i-lucide-chevron-down"
            trailing-icon
            size="xs"
            variant="faded"
            color="slate"
            @click="openSourceMenu = !openSourceMenu"
          />
          <DropdownMenu
            v-if="openSourceMenu"
            :menu-items="sourceOptions"
            class="top-full mt-1 ltr:left-0 rtl:right-0 z-20 min-w-40"
            @action="handleSourceSelect"
          />
        </div>
        <div
          v-if="documentIdFilter"
          class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium bg-n-brand/10 text-n-brand dark:bg-n-brand/20"
        >
          <span>
            {{
              $t('CAPTAIN.RESPONSES.FILTERS.FROM_SOURCE', {
                name: activeDocumentName,
              })
            }}
          </span>
          <button
            type="button"
            class="hover:opacity-75"
            @click="clearDocumentFilter"
          >
            <Icon icon="i-lucide-x" class="size-3" />
          </button>
        </div>
      </div>
    </template>

    <template #emptyState>
      <ResponsePageEmptyState @click="handleCreate" />
    </template>

    <template #paywall>
      <CaptainPaywall />
    </template>

    <template #body>
      <LimitBanner class="mb-5" />
      <Banner
        v-if="suggestionCount > 0"
        color="blue"
        class="mb-4 -mt-3"
        :action-label="$t('CAPTAIN.RESPONSES.SUGGESTIONS_BANNER.ACTION')"
        @action="navigateToFaqSuggestions"
      >
        {{ $t('CAPTAIN.RESPONSES.SUGGESTIONS_BANNER.TITLE') }}
      </Banner>

      <div class="flex flex-col gap-4">
        <ResponseCard
          v-for="response in responses"
          :id="response.id"
          :key="response.id"
          :question="response.question"
          :answer="response.answer"
          :assistant="response.assistant"
          :documentable="response.documentable"
          :status="response.status"
          :origin="response.origin"
          :enabled="response.enabled !== false"
          :created-at="response.created_at"
          :updated-at="response.updated_at"
          :used-in-conversations-count="response.used_in_conversations_count"
          :is-selected="bulkSelectedIds.has(response.id)"
          :selectable="hoveredCard === response.id || bulkSelectedIds.size > 0"
          :show-menu="!bulkSelectedIds.has(response.id)"
          :show-actions="false"
          @action="handleAction"
          @navigate="handleNavigationAction"
          @select="handleCardSelect"
          @toggle="handleToggleResponse"
          @hover="isHovered => handleCardHover(isHovered, response.id)"
          @view-conversations="handleShowResponseUsage"
        />
      </div>
    </template>

    <ConversationUsageDrawer
      :open="showResponseUsage"
      :resource-id="usageResponse?.id"
      :title="usageResponse?.question || ''"
      :conversation-count="usageResponse?.used_in_conversations_count || 0"
      :fetcher="fetchResponseUsage"
      empty-state-key="CAPTAIN.RESPONSES.NO_USED_CONVERSATIONS"
      @close="handleResponseUsageClose"
    />

    <DeleteDialog
      v-if="selectedResponse"
      ref="deleteDialog"
      :entity="selectedResponse"
      type="Responses"
      @delete-success="onDeleteSuccess"
    />

    <BulkDeleteDialog
      v-if="bulkSelectedIds"
      ref="bulkDeleteDialog"
      :bulk-ids="bulkSelectedIds"
      type="AssistantResponse"
      @delete-success="onBulkDeleteSuccess"
    />

    <CreateResponseDialog
      v-if="dialogType"
      ref="createDialog"
      :type="dialogType"
      :selected-response="selectedResponse"
      @close="handleCreateClose"
    />
  </PageLayout>
</template>

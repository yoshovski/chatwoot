<script setup>
import { computed, onUnmounted, ref, nextTick, watch } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { debounce } from '@chatwoot/utils';
import CaptainResponseAPI from 'dashboard/api/captain/response';

import Banner from 'dashboard/components-next/banner/Banner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import DeleteDialog from 'dashboard/components-next/captain/pageComponents/DeleteDialog.vue';
import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import TestAgentButton from 'dashboard/components-next/captain/TestAgentButton.vue';
import CaptainPaywall from 'dashboard/components-next/captain/pageComponents/Paywall.vue';
import FaqRow from 'dashboard/components-next/captain/list/FaqRow.vue';
import ListHeader from 'dashboard/components-next/captain/list/ListHeader.vue';
import KnowledgeBulkActions from 'dashboard/components-next/captain/list/KnowledgeBulkActions.vue';
import { useListSelection } from 'dashboard/components-next/captain/list/useListSelection';
import { usePolicy } from 'dashboard/composables/usePolicy';
import CreateResponseDialog from 'dashboard/components-next/captain/pageComponents/response/CreateResponseDialog.vue';
import ResponsePageEmptyState from 'dashboard/components-next/captain/pageComponents/emptyStates/ResponsePageEmptyState.vue';
import LimitBanner from 'dashboard/components-next/captain/pageComponents/response/LimitBanner.vue';
import ConversationUsageDrawer from 'dashboard/components-next/captain/pageComponents/ConversationUsageDrawer.vue';

const router = useRouter();
const route = useRoute();
const store = useStore();
const uiFlags = useMapGetter('captainResponses/getUIFlags');
const responseMeta = useMapGetter('captainResponses/getMeta');
const responses = useMapGetter('captainResponses/getRecords');
const isFetching = computed(() => uiFlags.value.fetchingList);

const selectedResponse = ref(null);
const usageResponse = ref(null);
const showResponseUsage = ref(false);
const deleteDialog = ref(null);

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

const { checkPermissions } = usePolicy();
const canManage = computed(() => checkPermissions(['administrator']));

const selection = useListSelection({
  items: responses,
  total: computed(() => responseMeta.value?.totalCount || 0),
  filters: () => ({
    assistant_id: selectedAssistantId.value || undefined,
    search: searchQuery.value || undefined,
    document_id: documentIdFilter.value || undefined,
    origin: sourceTypeFilter.value || undefined,
  }),
});

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

const SOURCE_OPTIONS = [
  {
    labelKey: 'CAPTAIN.RESPONSES.FILTERS.SOURCE.ALL',
    value: null,
    icon: 'i-lucide-files',
  },
  {
    labelKey: 'KNOWLEDGE_LIST.ORIGIN.FROM_PAGE',
    value: 'page',
    icon: 'i-lucide-globe',
  },
  {
    labelKey: 'KNOWLEDGE_LIST.ORIGIN.FROM_FILE',
    value: 'file',
    icon: 'i-lucide-file-text',
  },
  {
    labelKey: 'KNOWLEDGE_LIST.ORIGIN.BY_HAND',
    value: 'hand',
    icon: 'i-lucide-pencil',
  },
  {
    labelKey: 'KNOWLEDGE_LIST.ORIGIN.FROM_CONVERSATION',
    value: 'conversation',
    icon: 'i-lucide-messages-square',
  },
];

const sourceOptions = computed(() =>
  SOURCE_OPTIONS.map(option => ({
    label: t(option.labelKey),
    value: option.value,
    icon: option.icon,
    isSelected: option.value === sourceTypeFilter.value,
  }))
);

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
    filterParams.origin = sourceTypeFilter.value;
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
  selection.clear();
  fetchResponses(1);
};

const clearDocumentFilter = () => {
  documentIdFilter.value = null;
  fetchResponses(1);
};

const fetchResponsesAfterBulkDelete = () => {
  const currentPage = responseMeta.value?.page || 1;
  const hasNoResponsesLeft = responses.value?.length === 0;
  fetchResponses(hasNoResponsesLeft && currentPage > 1 ? currentPage - 1 : 1);
};

const hasActiveFilters = computed(
  () =>
    Boolean(searchQuery.value) ||
    Boolean(documentIdFilter.value) ||
    Boolean(sourceTypeFilter.value)
);

const clearFilters = () => {
  searchQuery.value = '';
  documentIdFilter.value = null;
  sourceTypeFilter.value = null;
  selection.clear();
  fetchResponses(1);
};

const onPageChange = page => {
  showResponseUsage.value = false;
  usageResponse.value = null;
  selection.clear();
  fetchResponses(page);
};

const onDeleteSuccess = () => {
  if (responses.value?.length === 0 && responseMeta.value?.page > 1) {
    onPageChange(responseMeta.value.page - 1);
  }
};

const debouncedSearch = debounce(async () => {
  fetchResponses(1);
}, 500);

const handleSearchInput = () => {
  abortListRequest();
  selection.clear();
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
    selection.clear();
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
    :header-title="$t('PLATFORM_NAV.FAQS')"
    :show-know-more="false"
    :button-label="$t('CAPTAIN.RESPONSES.ADD_NEW')"
    :is-fetching="isFetching"
    :is-empty="!responses.length && !hasActiveFilters"
    :show-pagination-footer="!isFetching && !!responses.length"
    :feature-flag="FEATURE_FLAGS.CAPTAIN"
    @update:current-page="onPageChange"
    @click="handleCreate"
  >
    <template #headerActions>
      <TestAgentButton :assistant-id="selectedAssistantId" />
    </template>
    <template #subHeader>
      <div class="flex flex-wrap items-center gap-2 mb-3">
        <Input
          v-model="searchQuery"
          :placeholder="$t('CAPTAIN.RESPONSES.SEARCH_PLACEHOLDER')"
          class="max-w-64 min-w-0 w-full"
          size="sm"
          type="search"
          @input="handleSearchInput"
        />
        <div v-on-clickaway="() => (openSourceMenu = false)" class="relative">
          <Button
            icon="i-lucide-layers"
            slate
            size="sm"
            :class="{ 'bg-n-slate-9/10': openSourceMenu }"
            @click="openSourceMenu = !openSourceMenu"
          >
            <span class="min-w-0 truncate">{{ currentSourceLabel }}</span>
            <Icon icon="i-lucide-chevron-down" class="shrink-0 size-4" />
          </Button>
          <DropdownMenu
            v-if="openSourceMenu"
            :menu-items="sourceOptions"
            class="top-full mt-2 ltr:left-0 rtl:right-0 z-30 min-w-56"
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

      <section
        :aria-label="$t('PLATFORM_NAV.FAQS')"
        class="border rounded-xl border-n-weak bg-n-solid-1"
      >
        <ListHeader
          :selection="selection"
          :selectable="canManage"
          :label="$t('KNOWLEDGE_LIST.COLUMNS.QUESTION')"
          :columns="['from', 'updated', 'inUse', 'actions']"
        >
          <Button
            v-if="hasActiveFilters"
            :label="$t('PLATFORM_NAV.CLEAR_FILTERS')"
            size="xs"
            variant="link"
            @click="clearFilters"
          />
        </ListHeader>
        <FaqRow
          v-for="response in responses"
          :id="response.id"
          :key="response.id"
          :question="response.question"
          :answer="response.answer"
          :documentable="response.documentable"
          :enabled="response.enabled !== false"
          :updated-at="response.updated_at || response.created_at"
          :used-in-conversations-count="response.used_in_conversations_count"
          :can-manage="canManage"
          :is-selected="selection.isSelected(response.id)"
          @action="handleAction"
          @navigate="handleNavigationAction"
          @select="selection.toggle"
          @toggle="handleToggleResponse"
          @view-conversations="handleShowResponseUsage"
        />
      </section>
      <KnowledgeBulkActions
        v-if="canManage"
        type="AssistantResponse"
        :selection="selection"
        :total="responseMeta.totalCount || 0"
        @updated="fetchResponses(responseMeta.page)"
        @deleted="fetchResponsesAfterBulkDelete"
      />
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

    <CreateResponseDialog
      v-if="dialogType"
      ref="createDialog"
      :type="dialogType"
      :selected-response="selectedResponse"
      @close="handleCreateClose"
    />
  </PageLayout>
</template>

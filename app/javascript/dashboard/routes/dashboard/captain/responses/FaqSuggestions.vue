<script setup>
import { computed, nextTick, onUnmounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { debounce } from '@chatwoot/utils';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import CaptainFaqSuggestionsAPI from 'dashboard/api/captain/faqSuggestions';
import CaptainKnowledgeGapsAPI from 'dashboard/api/captain/knowledgeGaps';

import Button from 'dashboard/components-next/button/Button.vue';
import CaptainPaywall from 'dashboard/components-next/captain/pageComponents/Paywall.vue';
import EmptyStateLayout from 'dashboard/components-next/EmptyStateLayout.vue';
import FaqSuggestionCard from 'dashboard/components-next/captain/assistant/FaqSuggestionCard.vue';
import FaqSuggestionReviewDialog from 'dashboard/components-next/captain/pageComponents/response/FaqSuggestionReviewDialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ActionRequestsCard from 'dashboard/components-next/captain/suggestions/ActionRequestsCard.vue';
import KitEmptyState from 'dashboard/components-next/kit/EmptyState.vue';
import SuggestionsFocus from 'dashboard/components-next/captain/suggestions/SuggestionsFocus.vue';
import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';

const TABS = { UNANSWERED: 'unanswered', ANSWERED: 'answered' };

const route = useRoute();
const router = useRouter();
const store = useStore();
const { t } = useI18n();

const suggestions = useMapGetter('captainFaqSuggestions/getRecords');
const suggestionMeta = useMapGetter('captainFaqSuggestions/getMeta');
const uiFlags = useMapGetter('captainFaqSuggestions/getUIFlags');

const searchQuery = ref('');
const selectedSuggestion = ref(null);
const reviewDialog = ref(null);
const activeSuggestionId = ref(null);

const activeTab = ref(TABS.UNANSWERED);
const topicGroups = ref([]);
const actionRequests = ref([]);
const isFetchingGaps = ref(false);
const hasGapsError = ref(false);
const busyGapIds = ref([]);
// Questions handled since the page opened: drives the progress bar and the "all done" state.
const handledCount = ref(0);
const gaps = computed(() => topicGroups.value.flatMap(group => group.gaps));
const gapsMeta = computed(() => ({ page: 1, totalCount: gaps.value.length }));
const isUnanswered = computed(() => activeTab.value === TABS.UNANSWERED);

const selectedAssistantId = computed(() => Number(route.params.assistantId));
const isFetching = computed(() =>
  isUnanswered.value ? isFetchingGaps.value : uiFlags.value.fetchingList
);
const isMutating = computed(
  () => uiFlags.value.updatingItem || uiFlags.value.deletingItem
);
const hasActiveFilters = computed(() => Boolean(searchQuery.value));

const tabs = computed(() => [
  {
    key: TABS.UNANSWERED,
    label: t('CAPTAIN.KNOWLEDGE_GAPS.TABS.UNANSWERED'),
    count: gapsMeta.value.totalCount,
  },
  {
    key: TABS.ANSWERED,
    label: t('CAPTAIN.KNOWLEDGE_GAPS.TABS.ANSWERED'),
    count: suggestionMeta.value.totalCount,
  },
]);
const activeTabIndex = computed(() =>
  tabs.value.findIndex(tab => tab.key === activeTab.value)
);
const listMeta = computed(() =>
  isUnanswered.value ? gapsMeta.value : suggestionMeta.value
);
const isListEmpty = computed(() =>
  isUnanswered.value
    ? !hasGapsError.value &&
      !handledCount.value &&
      !gaps.value.length &&
      !actionRequests.value.length
    : !suggestions.value.length
);

const updateURL = page => {
  const query = { tab: activeTab.value, page: page || 1 };
  if (searchQuery.value) query.search = searchQuery.value;
  router.replace({ query });
};

const { run: runListRequest, abort: abortListRequest } = useAbortableRequest();
const { run: runGapsRequest, abort: abortGapsRequest } = useAbortableRequest();

// The Unanswered tab is one page: questions grouped by topic, and the action requests.
const fetchGaps = async ({ quiet = false } = {}) => {
  if (!quiet) isFetchingGaps.value = true;
  hasGapsError.value = false;
  try {
    const params = {
      search: searchQuery.value,
      assistantId: selectedAssistantId.value,
    };
    const response = await runGapsRequest(signal =>
      Promise.all([
        CaptainKnowledgeGapsAPI.topics({ ...params, signal }),
        CaptainKnowledgeGapsAPI.actionRequests({ ...params, signal }),
      ])
    );
    if (!response) return;

    const [topicsResponse, actionsResponse] = response;
    topicGroups.value = topicsResponse.data.payload;
    actionRequests.value = actionsResponse.data.payload;
    isFetchingGaps.value = false;
  } catch {
    hasGapsError.value = true;
    isFetchingGaps.value = false;
  }
};

const fetchSuggestions = async (page = 1) => {
  store.dispatch('captainFaqSuggestions/setFetchingList', true);

  try {
    const response = await runListRequest(signal =>
      CaptainFaqSuggestionsAPI.get({
        page,
        search: searchQuery.value,
        assistantId: selectedAssistantId.value,
        signal,
      })
    );

    if (!response) return;

    store.dispatch('captainFaqSuggestions/setRecords', {
      records: response.data.payload,
      meta: response.data.meta,
    });
    store.dispatch('captainFaqSuggestions/setFetchingList', false);
  } catch (error) {
    useAlert(error?.message || t('CAPTAIN.FAQ_SUGGESTIONS.ERRORS.LOAD'));
    store.dispatch('captainFaqSuggestions/setFetchingList', false);
  }
};

const fetchActivePage = (page = 1) => {
  updateURL(page);
  return isUnanswered.value ? fetchGaps() : fetchSuggestions(page);
};

// Both lists load so each tab shows its count; the inactive one starts at page 1.
const fetchBothLists = page => {
  updateURL(page);
  fetchGaps();
  fetchSuggestions(isUnanswered.value ? 1 : page);
};

const handleTabChange = tab => {
  activeTab.value = tab.key;
  updateURL(listMeta.value.page);
};

// Runs one change on some questions, shows the result and reloads the list.
const changeGaps = async (ids, request, successMessage, errorMessage) => {
  busyGapIds.value = ids;
  try {
    await request();
    useAlert(successMessage);
    handledCount.value += ids.length;
    await fetchGaps({ quiet: true });
  } catch (error) {
    useAlert(error?.message || errorMessage);
  } finally {
    busyGapIds.value = [];
  }
};

const handleGapDismiss = gap =>
  changeGaps(
    [gap.id],
    () => CaptainKnowledgeGapsAPI.dismiss(gap.id),
    t('CAPTAIN.SUGGESTIONS.SUCCESS.DISMISSED'),
    t('CAPTAIN.KNOWLEDGE_GAPS.ERRORS.DISMISS')
  );

const handleBulkDismiss = ids =>
  changeGaps(
    ids,
    () => CaptainKnowledgeGapsAPI.bulkDismiss(ids),
    t('CAPTAIN.SUGGESTIONS.SUCCESS.BULK_DISMISSED', { count: ids.length }),
    t('CAPTAIN.KNOWLEDGE_GAPS.ERRORS.DISMISS')
  );

const handleGapSave = (gap, answer) =>
  changeGaps(
    [gap.id],
    () => CaptainKnowledgeGapsAPI.answer(gap.id, answer),
    t('CAPTAIN.KNOWLEDGE_GAPS.SUCCESS.ANSWERED'),
    t('CAPTAIN.KNOWLEDGE_GAPS.ERRORS.ANSWER')
  );

const refreshCurrentPage = () => {
  const currentPage = suggestionMeta.value.page || 1;
  const page =
    suggestions.value.length || currentPage === 1
      ? currentPage
      : currentPage - 1;
  fetchSuggestions(page);
};

const handleApprove = async suggestion => {
  activeSuggestionId.value = suggestion.id;
  try {
    await store.dispatch('captainFaqSuggestions/approve', {
      id: suggestion.id,
      question: suggestion.question,
      answer: suggestion.answer,
    });
    useAlert(t('CAPTAIN.FAQ_SUGGESTIONS.SUCCESS.APPROVED'));
    refreshCurrentPage();
  } catch (error) {
    useAlert(error?.message || t('CAPTAIN.FAQ_SUGGESTIONS.ERRORS.APPROVE'));
  } finally {
    activeSuggestionId.value = null;
  }
};

const handleDismiss = async suggestion => {
  activeSuggestionId.value = suggestion.id;
  try {
    await store.dispatch('captainFaqSuggestions/dismiss', suggestion.id);
    useAlert(t('CAPTAIN.FAQ_SUGGESTIONS.SUCCESS.DISMISSED'));
    refreshCurrentPage();
  } catch (error) {
    useAlert(error?.message || t('CAPTAIN.FAQ_SUGGESTIONS.ERRORS.DISMISS'));
  } finally {
    activeSuggestionId.value = null;
  }
};

const handleReview = suggestion => {
  selectedSuggestion.value = suggestion;
  nextTick(() => reviewDialog.value.dialogRef.open());
};

const handleReviewClose = () => {
  selectedSuggestion.value = null;
};

const handleResolved = () => {
  refreshCurrentPage();
};

const debouncedSearch = debounce(() => fetchBothLists(1), 500);

const handleSearchInput = () => {
  abortListRequest();
  abortGapsRequest();
  debouncedSearch();
};

const clearFilters = () => {
  searchQuery.value = '';
  fetchBothLists(1);
};

const initializeFromURL = () => {
  searchQuery.value = route.query.search || '';
  activeTab.value =
    route.query.tab === TABS.ANSWERED ? TABS.ANSWERED : TABS.UNANSWERED;
  fetchBothLists(parseInt(route.query.page, 10) || 1);
};

watch(
  selectedAssistantId,
  () => {
    selectedSuggestion.value = null;
    activeSuggestionId.value = null;
    topicGroups.value = [];
    actionRequests.value = [];
    handledCount.value = 0;
    store.dispatch('captainFaqSuggestions/setRecords', {
      records: [],
      meta: { page: 1, total_count: 0 },
    });
    initializeFromURL();
  },
  { immediate: true }
);

onUnmounted(() => {
  store.dispatch('captainFaqSuggestions/setFetchingList', false);
});
</script>

<template>
  <PageLayout
    :total-count="listMeta.totalCount"
    :current-page="listMeta.page"
    :header-title="$t('CAPTAIN.AGENT_UX.SECTIONS.KNOWLEDGE')"
    :is-fetching="isFetching"
    :is-empty="isListEmpty"
    :show-pagination-footer="
      !isUnanswered && !isFetching && (listMeta?.totalCount || 0) > 25
    "
    :show-know-more="false"
    :feature-flag="FEATURE_FLAGS.CAPTAIN"
    @update:current-page="fetchActivePage"
  >
    <template #search>
      <Input
        v-model="searchQuery"
        :placeholder="$t('CAPTAIN.FAQ_SUGGESTIONS.SEARCH_PLACEHOLDER')"
        class="w-64"
        size="sm"
        type="search"
        autofocus
        @input="handleSearchInput"
      />
    </template>

    <template #subHeader>
      <div class="mb-3">
        <TabBar
          :tabs="tabs"
          :initial-active-tab="activeTabIndex"
          @tab-changed="handleTabChange"
        />
      </div>
      <p
        v-if="isUnanswered && gaps.length"
        class="mb-2 text-sm text-n-slate-11"
      >
        {{ $t('CAPTAIN.SUGGESTIONS.HINT') }}
      </p>
      <div
        v-if="!isUnanswered && suggestions.length"
        class="mb-2 flex items-center gap-2 text-sm text-n-slate-11"
      >
        <span class="font-medium text-n-slate-12">
          {{
            $t('CAPTAIN.FAQ_SUGGESTIONS.QUEUE_COUNT', {
              count: suggestionMeta.totalCount,
            })
          }}
        </span>
        <span class="border-s border-n-weak ps-2">
          {{ $t('CAPTAIN.FAQ_SUGGESTIONS.QUEUE_HINT') }}
        </span>
      </div>
    </template>

    <template #emptyState>
      <EmptyStateLayout
        :title="
          isUnanswered
            ? $t('CAPTAIN.SUGGESTIONS.EMPTY_STATE.TITLE')
            : $t('CAPTAIN.FAQ_SUGGESTIONS.EMPTY_STATE.TITLE')
        "
        :subtitle="
          isUnanswered
            ? $t('CAPTAIN.SUGGESTIONS.EMPTY_STATE.SUBTITLE')
            : $t('CAPTAIN.FAQ_SUGGESTIONS.EMPTY_STATE.SUBTITLE')
        "
        :show-backdrop="false"
      >
        <template #actions>
          <Button
            v-if="hasActiveFilters"
            :label="$t('CAPTAIN.FAQ_SUGGESTIONS.EMPTY_STATE.CLEAR_SEARCH')"
            variant="link"
            size="sm"
            @click="clearFilters"
          />
        </template>
      </EmptyStateLayout>
    </template>

    <template #paywall>
      <CaptainPaywall />
    </template>
    <template #body>
      <div v-if="isUnanswered" class="mb-6 flex flex-col gap-5">
        <KitEmptyState
          v-if="hasGapsError"
          tone="error"
          class="rounded-card bg-n-solid-2 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
          icon="i-lucide-circle-alert"
          :title="$t('CAPTAIN.SUGGESTIONS.ERROR.TITLE')"
          :description="$t('CAPTAIN.SUGGESTIONS.ERROR.DESCRIPTION')"
        >
          <Button
            :label="$t('CAPTAIN.SUGGESTIONS.ERROR.RETRY')"
            size="sm"
            variant="faded"
            color="slate"
            @click="fetchGaps()"
          />
        </KitEmptyState>
        <SuggestionsFocus
          v-else-if="gaps.length"
          :topics="topicGroups"
          :busy-ids="busyGapIds"
          :handled-count="handledCount"
          @save="handleGapSave"
          @dismiss="handleGapDismiss"
          @bulk-dismiss="handleBulkDismiss"
        >
          <ActionRequestsCard
            v-if="actionRequests.length"
            :requests="actionRequests"
          />
        </SuggestionsFocus>
        <template v-else>
          <KitEmptyState
            v-if="handledCount"
            tone="success"
            class="rounded-card bg-n-solid-2 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
            icon="i-lucide-party-popper"
            :title="$t('CAPTAIN.SUGGESTIONS.DONE.TITLE')"
            :description="$t('CAPTAIN.SUGGESTIONS.DONE.DESCRIPTION')"
          />
          <p
            v-else
            class="mb-0 rounded-card bg-n-solid-2 p-5 text-sm text-n-slate-11 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
          >
            {{ $t('CAPTAIN.SUGGESTIONS.EMPTY_STATE.ONLY_ACTIONS') }}
          </p>
          <ActionRequestsCard
            v-if="actionRequests.length"
            :requests="actionRequests"
          />
        </template>
      </div>
      <section
        v-else
        :aria-label="$t('CAPTAIN.KNOWLEDGE_GAPS.TABS.ANSWERED')"
        class="border rounded-xl border-n-weak bg-n-solid-1 overflow-hidden mb-6"
      >
        <div
          class="flex items-center gap-3 px-4 py-2.5 text-xs font-medium border-b border-n-weak text-n-slate-11 bg-n-alpha-1"
        >
          <span class="flex-1 min-w-0">
            {{ $t('KNOWLEDGE_LIST.COLUMNS.QUESTION') }}
          </span>
          <span class="hidden sm:block w-36">
            {{ $t('KNOWLEDGE_LIST.COLUMNS.DEMAND') }}
          </span>
          <span class="hidden md:block w-28">
            {{ $t('KNOWLEDGE_LIST.COLUMNS.UPDATED') }}
          </span>
          <span class="sm:w-64 shrink-0 text-end" />
        </div>
        <FaqSuggestionCard
          v-for="suggestion in suggestions"
          :key="suggestion.id"
          :suggestion="suggestion"
          :is-loading="isMutating && activeSuggestionId === suggestion.id"
          @approve="handleApprove"
          @dismiss="handleDismiss"
          @review="handleReview"
        />
      </section>
    </template>

    <FaqSuggestionReviewDialog
      v-if="selectedSuggestion"
      ref="reviewDialog"
      :suggestion="selectedSuggestion"
      @close="handleReviewClose"
      @resolved="handleResolved"
    />
  </PageLayout>
</template>

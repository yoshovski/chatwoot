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
import KnowledgeGapAnswerDialog from 'dashboard/components-next/captain/pageComponents/response/KnowledgeGapAnswerDialog.vue';
import KnowledgeGapCard from 'dashboard/components-next/captain/assistant/KnowledgeGapCard.vue';
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
const gaps = ref([]);
const gapsMeta = ref({ page: 1, totalCount: 0 });
const isFetchingGaps = ref(false);
const selectedGap = ref(null);
const gapDialog = ref(null);
const activeGapId = ref(null);
const isUnanswered = computed(() => activeTab.value === TABS.UNANSWERED);

const selectedAssistantId = computed(() => Number(route.params.assistantId));
const isFetching = computed(() =>
  isUnanswered.value ? isFetchingGaps.value : uiFlags.value.fetchingList
);
const isMutating = computed(
  () => uiFlags.value.updatingItem || uiFlags.value.deletingItem
);
const hasActiveFilters = computed(() => Boolean(searchQuery.value));

const backUrl = computed(() => ({
  name: 'captain_assistants_responses_index',
  params: {
    accountId: route.params.accountId,
    assistantId: selectedAssistantId.value,
  },
}));

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
  isUnanswered.value ? !gaps.value.length : !suggestions.value.length
);

const updateURL = page => {
  const query = { tab: activeTab.value, page: page || 1 };
  if (searchQuery.value) query.search = searchQuery.value;
  router.replace({ query });
};

const { run: runListRequest, abort: abortListRequest } = useAbortableRequest();
const { run: runGapsRequest, abort: abortGapsRequest } = useAbortableRequest();

const fetchGaps = async (page = 1) => {
  isFetchingGaps.value = true;
  try {
    const response = await runGapsRequest(signal =>
      CaptainKnowledgeGapsAPI.get({
        page,
        search: searchQuery.value,
        assistantId: selectedAssistantId.value,
        signal,
      })
    );
    if (!response) return;

    gaps.value = response.data.payload;
    gapsMeta.value = {
      page: Number(response.data.meta.page),
      totalCount: response.data.meta.total_count,
    };
    isFetchingGaps.value = false;
  } catch (error) {
    useAlert(error?.message || t('CAPTAIN.KNOWLEDGE_GAPS.ERRORS.LOAD'));
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
  return isUnanswered.value ? fetchGaps(page) : fetchSuggestions(page);
};

// Both lists load so each tab shows its count; the inactive one starts at page 1.
const fetchBothLists = page => {
  updateURL(page);
  fetchGaps(isUnanswered.value ? page : 1);
  fetchSuggestions(isUnanswered.value ? 1 : page);
};

const handleTabChange = tab => {
  activeTab.value = tab.key;
  updateURL(listMeta.value.page);
};

const handleGapAnswer = gap => {
  selectedGap.value = gap;
  nextTick(() => gapDialog.value.dialogRef.open());
};

const handleGapDialogClose = () => {
  selectedGap.value = null;
};

const refreshGaps = () => {
  const currentPage = gapsMeta.value.page || 1;
  const page =
    gaps.value.length > 1 || currentPage === 1 ? currentPage : currentPage - 1;
  fetchGaps(page);
};

const handleGapDismiss = async gap => {
  activeGapId.value = gap.id;
  try {
    await CaptainKnowledgeGapsAPI.dismiss(gap.id);
    useAlert(t('CAPTAIN.KNOWLEDGE_GAPS.SUCCESS.DISMISSED'));
    refreshGaps();
  } catch (error) {
    useAlert(error?.message || t('CAPTAIN.KNOWLEDGE_GAPS.ERRORS.DISMISS'));
  } finally {
    activeGapId.value = null;
  }
};

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
    selectedGap.value = null;
    gaps.value = [];
    gapsMeta.value = { page: 1, totalCount: 0 };
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
    :header-title="$t('CAPTAIN.FAQ_SUGGESTIONS.HEADER')"
    :is-fetching="isFetching"
    :is-empty="isListEmpty"
    :show-pagination-footer="!isFetching && !isListEmpty"
    :show-know-more="false"
    :feature-flag="FEATURE_FLAGS.CAPTAIN"
    :back-url="backUrl"
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
        {{ $t('CAPTAIN.KNOWLEDGE_GAPS.QUEUE_HINT') }}
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
            ? $t('CAPTAIN.KNOWLEDGE_GAPS.EMPTY_STATE.TITLE')
            : $t('CAPTAIN.FAQ_SUGGESTIONS.EMPTY_STATE.TITLE')
        "
        :subtitle="
          isUnanswered
            ? $t('CAPTAIN.KNOWLEDGE_GAPS.EMPTY_STATE.SUBTITLE')
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
      <div v-if="isUnanswered" class="flex flex-col gap-3 pb-6">
        <KnowledgeGapCard
          v-for="gap in gaps"
          :key="gap.id"
          :gap="gap"
          :is-loading="activeGapId === gap.id"
          @answer="handleGapAnswer"
          @dismiss="handleGapDismiss"
        />
      </div>
      <div v-else class="flex flex-col gap-4 pb-6">
        <FaqSuggestionCard
          v-for="suggestion in suggestions"
          :key="suggestion.id"
          :suggestion="suggestion"
          :is-loading="isMutating && activeSuggestionId === suggestion.id"
          @approve="handleApprove"
          @dismiss="handleDismiss"
          @review="handleReview"
        />
      </div>
    </template>

    <FaqSuggestionReviewDialog
      v-if="selectedSuggestion"
      ref="reviewDialog"
      :suggestion="selectedSuggestion"
      @close="handleReviewClose"
      @resolved="handleResolved"
    />
    <KnowledgeGapAnswerDialog
      v-if="selectedGap"
      ref="gapDialog"
      :gap="selectedGap"
      @close="handleGapDialogClose"
      @resolved="refreshGaps"
    />
  </PageLayout>
</template>

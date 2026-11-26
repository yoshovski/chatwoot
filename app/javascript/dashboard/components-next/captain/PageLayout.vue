<script setup>
import { computed } from 'vue';
import { useSectionHeadingMatches } from 'dashboard/composables/useSectionHeading';
import { usePolicy } from 'dashboard/composables/usePolicy';
import Button from 'dashboard/components-next/button/Button.vue';
import BackButton from 'dashboard/components/widgets/BackButton.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Policy from 'dashboard/components/policy.vue';
import AgentSectionTabs from './AgentSectionTabs.vue';

const props = defineProps({
  currentPage: {
    type: Number,
    default: 1,
  },
  totalCount: {
    type: Number,
    default: 100,
  },
  itemsPerPage: {
    type: Number,
    default: 25,
  },
  headerTitle: {
    type: String,
    default: '',
  },
  backUrl: {
    type: [String, Object],
    default: '',
  },
  buttonPolicy: {
    type: Array,
    default: () => [],
  },
  buttonLabel: {
    type: String,
    default: '',
  },
  featureFlag: {
    type: String,
    default: '',
  },
  isFetching: {
    type: Boolean,
    default: false,
  },
  showKnowMore: {
    type: Boolean,
    default: true,
  },
  isEmpty: {
    type: Boolean,
    default: false,
  },
  showPaginationFooter: {
    type: Boolean,
    default: true,
  },
  containerClass: {
    type: String,
    default: 'max-w-[64rem]',
  },
});

const emit = defineEmits(['click', 'close', 'update:currentPage']);
const titleInTopBar = useSectionHeadingMatches(() => props.headerTitle);

const { shouldShowPaywall } = usePolicy();

const showPaywall = computed(() => {
  return shouldShowPaywall(props.featureFlag);
});

const handleButtonClick = () => {
  emit('click');
};

const handlePageChange = event => {
  emit('update:currentPage', event);
};
</script>

<template>
  <section
    class="workspace-content agent-workspace flex flex-col w-full h-full overflow-hidden bg-n-background"
  >
    <!-- Above positioned content of the page (tab bars use z-10), so header dropdowns open over it. -->
    <header
      class="workspace-widget workspace-inset sticky top-0 z-20 bg-n-background/90 backdrop-blur-md px-6"
    >
      <div
        class="w-full mx-auto"
        :class="[
          containerClass,
          { 'agent-overview-width': containerClass === 'max-w-[64rem]' },
        ]"
      >
        <div
          class="agent-toolbar flex w-full justify-between"
          :class="
            titleInTopBar
              ? 'flex-wrap items-center gap-2 py-2'
              : 'flex-col items-start gap-4 py-6 lg:h-20 lg:flex-row lg:items-center lg:gap-2 lg:py-0'
          "
        >
          <div class="flex gap-3 items-center">
            <BackButton v-if="backUrl" :back-url="backUrl" />
            <div class="flex items-center gap-4">
              <h1
                v-if="headerTitle && !titleInTopBar"
                class="mb-0 font-display text-2xl font-semibold tracking-display text-n-slate-12"
              >
                {{ headerTitle }}
              </h1>
              <div
                v-if="!isEmpty && showKnowMore"
                class="flex items-center gap-2"
              >
                <div
                  v-if="!titleInTopBar"
                  class="w-0.5 h-4 rounded-2xl bg-n-weak"
                />
                <slot name="knowMore" />
              </div>
            </div>
          </div>

          <div class="flex items-center gap-2">
            <slot name="headerActions" />
            <slot name="search" />
            <div
              v-if="!showPaywall && buttonLabel"
              v-on-clickaway="() => emit('close')"
              class="relative group/captain-button"
            >
              <Policy :permissions="buttonPolicy">
                <Button
                  :label="buttonLabel"
                  icon="i-lucide-plus"
                  size="sm"
                  class="group-hover/captain-button:brightness-110"
                  @click="handleButtonClick"
                />
              </Policy>
              <slot name="action" />
            </div>
          </div>
        </div>
        <AgentSectionTabs class="mb-4" />
        <slot name="subHeader" />
      </div>
    </header>
    <main class="flex-1 px-6 overflow-y-auto">
      <div
        class="w-full h-full py-4 mx-auto"
        :class="[
          containerClass,
          { 'agent-overview-width': containerClass === 'max-w-[64rem]' },
        ]"
      >
        <slot v-if="!showPaywall" name="controls" />
        <div
          v-if="isFetching"
          class="flex items-center justify-center py-10 text-n-slate-11"
        >
          <Spinner />
        </div>
        <div v-else-if="showPaywall">
          <slot name="paywall" />
        </div>
        <div v-else-if="isEmpty">
          <slot name="emptyState" />
        </div>
        <slot v-else name="body" />
        <slot />
      </div>
    </main>
    <footer v-if="showPaginationFooter" class="sticky bottom-0 z-10">
      <PaginationFooter
        :current-page="currentPage"
        :total-items="totalCount"
        :items-per-page="itemsPerPage"
        class="max-w-[64rem]"
        @update:current-page="handlePageChange"
      />
    </footer>
  </section>
</template>

<script setup>
import { computed, ref, watch } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

// One question in focus, as a card to work through, and a calm overview of all of them beside it. The default slot
// goes under the card (the action requests); on a phone it comes after the overview.
const props = defineProps({
  topics: { type: Array, default: () => [] },
  busyIds: { type: Array, default: () => [] },
  handledCount: { type: Number, default: 0 },
});

const emit = defineEmits(['save', 'dismiss', 'bulkDismiss']);

const gaps = computed(() => props.topics.flatMap(group => group.gaps));
const selectedId = ref(null);
const current = computed(
  () => gaps.value.find(gap => gap.id === selectedId.value) || gaps.value[0]
);
const currentIndex = computed(() => gaps.value.indexOf(current.value));
const total = computed(() => gaps.value.length + props.handledCount);
const progress = computed(() =>
  total.value ? Math.round((props.handledCount / total.value) * 100) : 0
);

const isEditing = ref(false);
const showAllQuotes = ref(false);
const answer = ref('');
watch(
  () => current.value?.id,
  () => {
    answer.value = current.value?.draft_answer || '';
    isEditing.value = !current.value?.draft_answer;
    showAllQuotes.value = false;
  },
  { immediate: true }
);

const quotes = computed(() => current.value?.examples || []);
const isBusy = computed(() => props.busyIds.includes(current.value?.id));
const next = () => {
  const list = gaps.value;
  selectedId.value = list[(currentIndex.value + 1) % list.length].id;
};
const save = () =>
  emit('save', current.value, {
    question: current.value.question,
    answer: answer.value.trim(),
  });

// Select mode in the overview, for marking several as not relevant at once.
const isSelecting = ref(false);
const selectedIds = ref([]);
watch(gaps, (list, oldList = []) => {
  selectedIds.value = selectedIds.value.filter(id =>
    list.some(gap => gap.id === id)
  );
  // When the question in focus was handled, the one that came after it takes its place.
  const focusedId = selectedId.value ?? oldList[0]?.id;
  if (list.some(gap => gap.id === focusedId)) return;
  const oldIndex = Math.max(
    oldList.findIndex(gap => gap.id === focusedId),
    0
  );
  selectedId.value = list[Math.min(oldIndex, list.length - 1)]?.id ?? null;
});
const toggleSelected = (id, value) => {
  selectedIds.value = value
    ? [...selectedIds.value, id]
    : selectedIds.value.filter(selected => selected !== id);
};
const stopSelecting = () => {
  isSelecting.value = false;
  selectedIds.value = [];
};
const bulkDismiss = () => {
  emit('bulkDismiss', [...selectedIds.value]);
  stopSelecting();
};
</script>

<template>
  <div class="grid items-start gap-5 lg:grid-cols-[minmax(0,1fr)_18rem]">
    <!-- The card in focus -->
    <article
      v-if="current"
      class="flex flex-col gap-5 rounded-card bg-n-solid-2 p-5 shadow-card outline outline-1 -outline-offset-1 outline-n-container sm:p-7 lg:col-start-1 lg:row-start-1"
    >
      <div class="flex items-center gap-3">
        <span
          class="rounded-full bg-n-alpha-2 px-2.5 py-0.5 text-xs font-medium text-n-slate-12"
        >
          {{ current.topic || $t('CAPTAIN.SUGGESTIONS.NO_TOPIC') }}
        </span>
        <span class="text-xs text-n-slate-11">
          {{
            $t('CAPTAIN.SUGGESTIONS.ASKED_IN', {
              count: current.occurrences_count,
            })
          }}
        </span>
      </div>

      <h2
        class="mb-0 font-display text-2xl font-semibold tracking-display text-n-slate-12"
      >
        {{ current.question }}
      </h2>

      <div v-if="quotes.length" class="flex flex-col gap-1.5">
        <p
          v-for="quote in showAllQuotes ? quotes : quotes.slice(0, 1)"
          :key="quote"
          class="mb-0 border-s-2 border-n-slate-6 ps-3 text-sm italic text-n-slate-11"
        >
          {{ $t('CAPTAIN.SUGGESTIONS.FOCUS.QUOTE', { text: quote }) }}
        </p>
        <button
          v-if="quotes.length > 1 && !showAllQuotes"
          type="button"
          class="w-fit p-0 ps-3.5 text-xs font-medium text-n-slate-11 hover:text-n-slate-12"
          @click="showAllQuotes = true"
        >
          {{
            $t('CAPTAIN.SUGGESTIONS.FOCUS.MORE_QUOTES', {
              count: quotes.length - 1,
            })
          }}
        </button>
      </div>

      <div
        v-if="!isEditing"
        class="flex flex-col gap-1 rounded-xl bg-n-teal-2 p-4 outline outline-1 -outline-offset-1 outline-n-teal-5"
      >
        <span class="text-xs font-medium text-n-teal-11">
          {{ $t('CAPTAIN.SUGGESTIONS.FOCUS.DRAFT') }}
        </span>
        <p class="mb-0 text-sm text-n-slate-12">{{ answer }}</p>
      </div>
      <TextArea
        v-else
        v-model="answer"
        :placeholder="$t('CAPTAIN.SUGGESTIONS.ANSWER_PLACEHOLDER')"
        auto-height
        min-height="5rem"
        max-height="14rem"
      />

      <div class="flex flex-wrap items-center gap-2">
        <Button
          :label="$t('CAPTAIN.SUGGESTIONS.FOCUS.ADD')"
          icon="i-lucide-check"
          :is-loading="isBusy"
          :disabled="!answer.trim() || isBusy"
          @click="save"
        />
        <Button
          v-if="!isEditing"
          :label="$t('CAPTAIN.SUGGESTIONS.FOCUS.EDIT')"
          variant="faded"
          color="slate"
          :disabled="isBusy"
          @click="isEditing = true"
        />
        <Button
          :label="$t('CAPTAIN.SUGGESTIONS.NOT_RELEVANT')"
          variant="ghost"
          color="slate"
          :disabled="isBusy"
          @click="emit('dismiss', current)"
        />
        <Button
          v-if="gaps.length > 1"
          :label="$t('CAPTAIN.SUGGESTIONS.FOCUS.NEXT')"
          icon="i-lucide-arrow-right"
          trailing-icon
          variant="ghost"
          color="slate"
          class="sm:ms-auto"
          :disabled="isBusy"
          @click="next"
        />
      </div>
    </article>

    <!-- The overview: every question, one line each -->
    <aside
      class="flex flex-col gap-4 rounded-card bg-n-solid-2 p-4 shadow-card outline outline-1 -outline-offset-1 outline-n-container lg:sticky lg:top-0 lg:col-start-2 lg:row-span-2 lg:row-start-1"
    >
      <div class="flex flex-col gap-2">
        <div class="flex items-baseline justify-between gap-2">
          <span class="text-sm font-semibold text-n-slate-12">
            {{ $t('CAPTAIN.SUGGESTIONS.FOCUS.LEFT', { count: gaps.length }) }}
          </span>
          <button
            type="button"
            class="p-0 text-xs font-medium text-n-slate-11 hover:text-n-slate-12"
            @click="isSelecting ? stopSelecting() : (isSelecting = true)"
          >
            {{
              isSelecting
                ? $t('CAPTAIN.SUGGESTIONS.BULK.CANCEL')
                : $t('CAPTAIN.SUGGESTIONS.BULK.SELECT')
            }}
          </button>
        </div>
        <div class="h-1.5 overflow-hidden rounded-full bg-n-alpha-2">
          <div
            class="h-full rounded-full bg-n-teal-9 transition-all"
            :style="{ width: `${progress}%` }"
          />
        </div>
      </div>

      <section
        v-for="group in topics"
        :key="group.topic || 'none'"
        class="flex flex-col gap-0.5"
      >
        <h3
          class="mb-1 text-[0.6875rem] font-semibold uppercase tracking-wide text-n-slate-10"
        >
          {{ group.topic || $t('CAPTAIN.SUGGESTIONS.NO_TOPIC') }}
        </h3>
        <component
          :is="isSelecting ? 'label' : 'button'"
          v-for="gap in group.gaps"
          :key="gap.id"
          :type="isSelecting ? undefined : 'button'"
          class="flex w-full cursor-pointer items-start gap-2 rounded-lg px-2 py-1.5 text-start text-sm transition-colors"
          :class="
            !isSelecting && gap.id === current?.id
              ? 'bg-n-blue-3 font-medium text-n-slate-12'
              : 'text-n-slate-11 hover:bg-n-alpha-1 hover:text-n-slate-12'
          "
          @click="isSelecting || (selectedId = gap.id)"
        >
          <Checkbox
            v-if="isSelecting"
            class="mt-0.5 shrink-0"
            :model-value="selectedIds.includes(gap.id)"
            @update:model-value="value => toggleSelected(gap.id, value)"
          />
          <span class="line-clamp-2 min-w-0 flex-1">{{ gap.question }}</span>
          <Icon
            v-if="gap.draft_answer && !isSelecting"
            v-tooltip.top="$t('CAPTAIN.SUGGESTIONS.FOCUS.HAS_DRAFT')"
            icon="i-lucide-sparkles"
            class="mt-0.5 size-3.5 shrink-0 text-n-teal-10"
          />
          <span class="shrink-0 text-xs tabular-nums text-n-slate-10">
            {{ gap.occurrences_count }}
          </span>
        </component>
      </section>

      <Button
        v-if="isSelecting"
        :label="
          $t('CAPTAIN.SUGGESTIONS.BULK.NOT_RELEVANT_COUNT', {
            count: selectedIds.length,
          })
        "
        size="sm"
        variant="faded"
        color="slate"
        :disabled="!selectedIds.length || busyIds.length > 0"
        @click="bulkDismiss"
      />
    </aside>

    <div class="flex min-w-0 flex-col gap-5 lg:col-start-1 lg:row-start-2">
      <slot />
    </div>
  </div>
</template>

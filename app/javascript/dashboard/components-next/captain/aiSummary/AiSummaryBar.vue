<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { onClickOutside, useTimeoutFn } from '@vueuse/core';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  SUMMARY_STATUS,
  summaryHeadline,
  useSummaryStatusLabel,
} from './aiSummary';

// The AI summary at the top of the thread: one sentence (what the customer wants → what to do next).
// Hovering or clicking opens the rest over the messages, so the thread never jumps.
const props = defineProps({
  summary: { type: Object, required: true },
});

const { t } = useI18n();
const statusLabel = useSummaryStatusLabel();
const OPEN_DELAY_MS = 200;

const headline = computed(() => summaryHeadline(props.summary));
const actions = computed(() => props.summary.actions || []);
const hasMore = computed(
  () =>
    !!props.summary.next_step ||
    !!props.summary.details ||
    !!props.summary.lead ||
    actions.value.length > 0 ||
    (!!props.summary.reason && !!props.summary.wants)
);

const root = ref(null);
const hovered = ref(false);
const pinned = ref(false);
const isOpen = computed(() => hasMore.value && (hovered.value || pinned.value));

const { start: openSoon, stop: cancelOpen } = useTimeoutFn(
  () => {
    hovered.value = true;
  },
  OPEN_DELAY_MS,
  { immediate: false }
);
const onEnter = () => openSoon();
const onLeave = () => {
  cancelOpen();
  hovered.value = false;
};
const close = () => {
  pinned.value = false;
  hovered.value = false;
};
onClickOutside(root, close);

const ACTION_ICON = {
  succeeded: { icon: 'i-lucide-check', tone: 'text-n-teal-11' },
  failed: { icon: 'i-lucide-x', tone: 'text-n-ruby-11' },
};
const actionIcon = outcome =>
  ACTION_ICON[outcome] || { icon: 'i-lucide-minus', tone: 'text-n-slate-10' };
</script>

<template>
  <div
    ref="root"
    class="relative h-11"
    data-test-id="ai-summary-bar"
    @mouseenter="onEnter"
    @mouseleave="onLeave"
    @keydown.esc="close"
  >
    <div
      class="absolute inset-x-0 top-0 z-10 overflow-hidden rounded-xl bg-gradient-to-r from-n-blue-2 via-n-iris-2 to-n-violet-2 outline outline-1 -outline-offset-1 outline-n-iris-4 transition-shadow duration-300"
      :class="isOpen ? 'shadow-card' : 'shadow-none'"
    >
      <button
        type="button"
        class="flex min-h-11 w-full min-w-0 items-center gap-2.5 px-3 py-2 text-start text-sm"
        :aria-expanded="isOpen"
        :aria-label="t('CONVERSATION.AI_SUMMARY.TITLE')"
        @click="pinned = !pinned"
      >
        <span
          class="grid size-6 shrink-0 place-items-center rounded-full bg-gradient-to-br from-n-blue-9 to-n-violet-9"
        >
          <Icon icon="i-lucide-sparkles" class="size-3.5 text-white" />
        </span>
        <span
          class="size-1.5 shrink-0 rounded-full"
          :class="SUMMARY_STATUS[summary.status]"
          :title="statusLabel(summary.status)"
        />
        <p
          class="mb-0 min-w-[8rem] text-n-slate-12"
          :class="isOpen ? 'whitespace-normal' : 'truncate'"
        >
          {{ headline }}
        </p>
        <span
          v-if="summary.next_step && !isOpen"
          class="hidden min-w-0 shrink-[3] items-center gap-1 font-medium text-n-iris-11 md:inline-flex"
        >
          <Icon icon="i-lucide-arrow-right" class="size-3.5 shrink-0" />
          <span class="min-w-0 truncate">{{ summary.next_step }}</span>
        </span>
        <Icon
          v-if="hasMore"
          icon="i-lucide-chevron-down"
          class="ms-auto size-4 shrink-0 text-n-slate-10 transition-transform duration-300"
          :class="{ 'rotate-180': isOpen }"
        />
      </button>

      <div
        class="grid transition-[grid-template-rows,opacity] duration-300 ease-out"
        :class="
          isOpen ? 'grid-rows-[1fr] opacity-100' : 'grid-rows-[0fr] opacity-0'
        "
      >
        <div class="min-h-0 overflow-hidden">
          <div class="flex flex-col gap-2.5 px-3 pb-3 ps-[3.25rem] text-sm">
            <p
              v-if="summary.next_step"
              class="mb-0 flex items-center gap-1 font-medium text-n-iris-11"
            >
              <Icon icon="i-lucide-arrow-right" class="size-3.5" />
              {{ summary.next_step }}
            </p>
            <p v-if="summary.details" class="mb-0 text-n-slate-11">
              {{ summary.details }}
            </p>
            <p
              v-if="summary.reason && summary.wants"
              class="mb-0 text-n-slate-11"
            >
              {{ summary.reason }}
            </p>
            <div
              v-if="summary.lead || actions.length"
              class="flex flex-wrap gap-1.5"
            >
              <span
                v-if="summary.lead"
                class="inline-flex items-center gap-1.5 rounded-full bg-n-solid-2 px-2.5 py-1 text-xs text-n-slate-12"
              >
                <Icon
                  icon="i-lucide-user-plus"
                  class="size-3.5 text-n-blue-11"
                />
                {{
                  t('CONVERSATION.AI_SUMMARY.LEAD_SAVED', {
                    type: summary.lead.type,
                  })
                }}
              </span>
              <span
                v-for="(action, index) in actions"
                :key="index"
                class="inline-flex items-center gap-1.5 rounded-full bg-n-solid-2 px-2.5 py-1 text-xs text-n-slate-12"
              >
                <Icon
                  :icon="actionIcon(action.outcome).icon"
                  class="size-3.5"
                  :class="actionIcon(action.outcome).tone"
                />
                {{ action.title }}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

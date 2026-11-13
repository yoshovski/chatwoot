<script setup>
import { computed } from 'vue';
import {
  SUMMARY_STATUS,
  summaryHeadline,
  useSummaryStatusLabel,
} from './aiSummary';

// The summary's one-line form under the message preview in the conversation list.
const props = defineProps({
  summary: { type: Object, required: true },
});

const statusLabel = useSummaryStatusLabel();
const headline = computed(() => summaryHeadline(props.summary));
</script>

<template>
  <p
    data-test-id="ai-summary-line"
    class="mx-2 my-0 flex min-w-0 items-center gap-1.5 text-xs leading-5 text-n-slate-11"
  >
    <span
      class="size-1.5 shrink-0 rounded-full"
      :class="SUMMARY_STATUS[summary.status]"
      :title="statusLabel(summary.status)"
    />
    <span class="truncate">{{ headline }}</span>
  </p>
</template>

<script setup>
import { computed, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import CaptainAssistant from 'dashboard/api/captain/assistant';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';

const props = defineProps({
  faqStats: { type: Object, default: null },
});
const route = useRoute();
const request = useAbortableRequest();
const stats = ref({ documents: 0, approved: 0 });
const effectiveStats = computed(() => props.faqStats || stats.value);
watch(
  () => route.params.assistantId,
  async id => {
    stats.value = { documents: 0, approved: 0 };
    if (!id || props.faqStats) return;
    try {
      const response = await request.run(signal =>
        CaptainAssistant.getFaqStats({ assistantId: Number(id), signal })
      );
      if (response) stats.value = response.data;
    } catch {
      /* Counts are supplementary; the content list reports load errors. */
    }
  },
  { immediate: true }
);
</script>

<template>
  <div class="mb-5 flex flex-col gap-2">
    <p class="m-0 text-sm text-n-slate-11">
      {{ $t('CAPTAIN.KNOWLEDGE.SUBTITLE') }}
    </p>
    <div class="flex flex-wrap items-center gap-2 text-xs text-n-slate-11">
      <span>{{
        $t('CAPTAIN.KNOWLEDGE.STATS.SOURCES', {
          count: effectiveStats.documents,
        })
      }}</span>
      <span class="size-1 rounded-full bg-n-slate-7" aria-hidden="true" />
      <span>{{
        $t('CAPTAIN.KNOWLEDGE.STATS.FAQS', { count: effectiveStats.approved })
      }}</span>
    </div>
  </div>
</template>

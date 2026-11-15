<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import AssistantWidgetTest from 'dashboard/components-next/captain/assistant/AssistantWidgetTest.vue';

const route = useRoute();
const assistantId = computed(() => Number(route.params.assistantId));
</script>

<template>
  <PageLayout
    :header-title="$t('CAPTAIN.PLAYGROUND.WIDGET_TEST.TITLE')"
    :show-pagination-footer="false"
    :show-know-more="false"
  >
    <template #body>
      <AssistantWidgetTest :key="assistantId" :assistant-id="assistantId" />
    </template>
  </PageLayout>
</template>

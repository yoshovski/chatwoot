<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useFunctionGetter, useMapGetter } from 'dashboard/composables/store';
import PageLayout from 'next/captain/PageLayout.vue';
import TestAgentButton from 'next/captain/TestAgentButton.vue';

defineProps({
  heading: { type: String, required: true },
  description: { type: String, default: '' },
  showTestAgent: { type: Boolean, default: true },
});

const route = useRoute();
const uiFlags = useMapGetter('captainAssistants/getUIFlags');
const assistantId = computed(() => Number(route.params.assistantId));
const assistant = useFunctionGetter('captainAssistants/getRecord', assistantId);
const isFetching = computed(
  () => uiFlags.value.fetchingItem && !assistant.value.id
);
</script>

<template>
  <PageLayout
    :header-title="heading"
    :is-fetching="isFetching"
    :show-know-more="false"
    :show-pagination-footer="false"
  >
    <template #headerActions>
      <TestAgentButton
        v-if="showTestAgent"
        :assistant-id="route.params.assistantId"
      />
      <slot name="headerActions" />
    </template>
    <template #body>
      <div class="flex min-w-0 flex-col w-full gap-6 pb-8">
        <p
          v-if="assistant.name && showTestAgent"
          class="m-0 break-words text-sm text-n-slate-11"
        >
          {{
            $t('CAPTAIN.AGENT_UX.CONFIGURATION.SCOPE', { name: assistant.name })
          }}
        </p>
        <p v-if="description" class="m-0 text-sm text-n-slate-11">
          {{ description }}
        </p>
        <slot />
      </div>
    </template>
  </PageLayout>
</template>

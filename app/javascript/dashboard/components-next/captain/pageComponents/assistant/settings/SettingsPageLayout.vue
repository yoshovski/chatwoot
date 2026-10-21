<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import PageLayout from 'next/captain/PageLayout.vue';

defineProps({
  heading: { type: String, required: true },
  description: { type: String, default: '' },
  showTestAgent: { type: Boolean, default: true },
});

const route = useRoute();
const assistantId = computed(() => route.params.assistantId);
const uiFlags = useMapGetter('captainAssistants/getUIFlags');
const isFetching = computed(() => uiFlags.value.fetchingItem);
</script>

<template>
  <PageLayout
    :header-title="heading"
    :is-fetching="isFetching"
    :show-know-more="false"
    :show-pagination-footer="false"
  >
    <template #headerActions>
      <router-link
        v-if="showTestAgent && assistantId"
        :to="{
          name: 'captain_assistants_playground_index',
          params: { accountId: route.params.accountId, assistantId },
        }"
      >
        <Button
          :label="$t('PLATFORM_NAV.TEST_AGENT')"
          icon="i-lucide-play"
          variant="outline"
          color="slate"
          size="sm"
        />
      </router-link>
      <slot name="headerActions" />
    </template>
    <template #body>
      <div class="flex w-full flex-col gap-6 pb-8">
        <p v-if="description" class="m-0 text-sm text-n-slate-11">
          {{ description }}
        </p>
        <slot />
      </div>
    </template>
  </PageLayout>
</template>

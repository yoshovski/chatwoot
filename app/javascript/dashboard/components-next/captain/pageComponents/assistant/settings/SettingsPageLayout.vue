<script setup>
import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import PageLayout from 'next/captain/PageLayout.vue';

defineProps({
  heading: { type: String, required: true },
  description: { type: String, default: '' },
});
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

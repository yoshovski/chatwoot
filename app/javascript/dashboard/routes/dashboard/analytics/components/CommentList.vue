<script setup>
import { useI18n } from 'vue-i18n';
import { RouterLink } from 'vue-router';
import { dynamicTime } from 'shared/helpers/timeHelper';
import EmptyState from 'dashboard/components-next/kit/EmptyState.vue';

// The latest ratings that came with a comment; each opens its conversation.
defineProps({
  // [{ id, rating, comment, name, at, conversationId }]
  comments: { type: Array, default: () => [] },
  isLoading: { type: Boolean, default: false },
});
const { t } = useI18n();
</script>

<template>
  <div v-if="isLoading" class="flex flex-col gap-3" aria-busy="true">
    <span
      v-for="n in 3"
      :key="n"
      class="h-12 w-full animate-pulse rounded bg-n-alpha-2"
    />
  </div>
  <EmptyState
    v-else-if="!comments.length"
    icon="i-lucide-message-square-quote"
    :title="t('ANALYTICS.RATING.NO_COMMENTS')"
  />
  <ul v-else class="m-0 flex list-none flex-col divide-y divide-n-weak p-0">
    <li v-for="item in comments" :key="item.id">
      <RouterLink
        :to="{
          name: 'inbox_conversation',
          params: { conversation_id: item.conversationId },
        }"
        class="flex flex-col gap-1 py-2.5"
      >
        <span class="line-clamp-2 text-sm text-n-slate-12">
          {{ t('ANALYTICS.RATING.QUOTE', { comment: item.comment }) }}
        </span>
        <span class="text-xs text-n-slate-11">
          {{
            t('ANALYTICS.RATING.COMMENT_META', {
              rating: item.rating,
              name: item.name || t('ANALYTICS.RATING.SOMEONE'),
              time: dynamicTime(item.at),
            })
          }}
        </span>
      </RouterLink>
    </li>
  </ul>
</template>

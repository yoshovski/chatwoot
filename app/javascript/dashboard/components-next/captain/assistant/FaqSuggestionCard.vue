<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { useExactTimestamp } from 'shared/composables/useExactTimestamp';

import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  suggestion: {
    type: Object,
    required: true,
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['approve', 'dismiss', 'review']);

const exactTimestamp = useExactTimestamp();

const { t } = useI18n();

const sourceLabel = computed(() =>
  t('CAPTAIN.FAQ_SUGGESTIONS.SOURCE_COUNT', {
    count: props.suggestion.source_count,
  })
);

const updatedAt = computed(() =>
  dynamicTime(props.suggestion.updated_at || props.suggestion.created_at)
);

const language = computed(() =>
  props.suggestion.language?.replace('_', '-').toUpperCase()
);
</script>

<template>
  <div
    class="group flex items-center gap-3 px-4 py-3 border-b border-n-weak last:border-b-0 transition-colors hover:bg-n-alpha-1"
  >
    <div
      class="flex items-center justify-center size-6 rounded shrink-0 bg-n-purple-3 text-n-purple-11 dark:bg-n-purple-3/20"
    >
      <Icon icon="i-lucide-sparkles" class="size-3.5" />
    </div>
    <div class="flex flex-col flex-1 min-w-0 gap-0.5">
      <button
        type="button"
        class="p-0 text-sm font-medium text-start bg-transparent border-0 outline-transparent line-clamp-2 text-n-slate-12 underline-offset-2 hover:underline focus-visible:underline"
        @click="emit('review', suggestion)"
      >
        {{ suggestion.question }}
      </button>
      <span class="text-xs text-n-slate-11 truncate">
        {{ suggestion.answer }}
      </span>
      <div class="flex sm:hidden items-center gap-2 mt-0.5">
        <span
          class="inline-flex items-center gap-1 rounded-full bg-n-brand/10 px-1.5 py-0.5 text-[11px] font-medium text-n-blue-11 dark:bg-n-brand/20"
        >
          <Icon icon="i-lucide-messages-square" class="size-3" />
          {{ sourceLabel }}
        </span>
      </div>
    </div>
    <div class="hidden sm:flex items-center w-36 shrink-0">
      <span
        class="inline-flex items-center gap-1.5 rounded-full bg-n-brand/10 px-2 py-0.5 text-xs font-medium text-n-blue-11 dark:bg-n-brand/20"
      >
        <Icon icon="i-lucide-messages-square" class="size-3" />
        {{ sourceLabel }}
      </span>
    </div>
    <div
      class="hidden md:flex items-center gap-1.5 w-36 shrink-0 text-xs text-n-slate-10"
    >
      <span
        v-if="language"
        class="rounded bg-n-alpha-2 px-1 py-0.5 text-[10px] font-medium text-n-slate-11 shrink-0"
      >
        {{ language }}
      </span>
      <span
        v-tooltip.top="{
          content: exactTimestamp(
            suggestion.updated_at || suggestion.created_at
          ),
          delay: { show: 500, hide: 0 },
        }"
        class="whitespace-nowrap"
      >
        {{ updatedAt }}
      </span>
    </div>
    <div class="flex items-center justify-end sm:w-64 shrink-0 gap-1.5">
      <Button
        type="button"
        :label="$t('CAPTAIN.FAQ_SUGGESTIONS.DISMISS')"
        size="xs"
        variant="ghost"
        color="slate"
        class="hidden sm:inline-flex"
        :disabled="isLoading"
        @click="emit('dismiss', suggestion)"
      />
      <Button
        type="button"
        :label="$t('CAPTAIN.FAQ_SUGGESTIONS.REVIEW')"
        icon="i-lucide-list-collapse"
        size="xs"
        variant="faded"
        color="slate"
        @click="emit('review', suggestion)"
      />
      <Button
        type="button"
        :label="$t('CAPTAIN.FAQ_SUGGESTIONS.APPROVE')"
        icon="i-lucide-circle-check-big"
        size="xs"
        :is-loading="isLoading"
        :disabled="isLoading"
        @click="emit('approve', suggestion)"
      />
    </div>
  </div>
</template>

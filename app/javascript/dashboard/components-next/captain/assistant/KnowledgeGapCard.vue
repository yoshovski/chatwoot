<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { useExactTimestamp } from 'shared/composables/useExactTimestamp';

import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  gap: {
    type: Object,
    required: true,
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['answer', 'dismiss']);

const { t } = useI18n();
const exactTimestamp = useExactTimestamp();

const lastSeen = computed(() => dynamicTime(props.gap.last_seen_at));

// Handoffs are the louder signal: the customer had to wait for a person.
const reasonLabel = computed(() =>
  props.gap.reasons?.handoff
    ? t('CAPTAIN.KNOWLEDGE_GAPS.REASON.HANDOFF')
    : t('CAPTAIN.KNOWLEDGE_GAPS.REASON.NO_SOURCE')
);
</script>

<template>
  <div
    class="group flex items-center gap-3 px-4 py-3 border-b border-n-weak last:border-b-0 transition-colors hover:bg-n-alpha-1"
  >
    <div
      class="flex items-center justify-center size-6 rounded shrink-0 bg-n-amber-3 text-n-amber-11 dark:bg-n-amber-3/20"
    >
      <Icon icon="i-lucide-circle-help" class="size-3.5" />
    </div>
    <div class="flex flex-col flex-1 min-w-0 gap-0.5">
      <button
        type="button"
        class="p-0 text-sm font-medium text-start bg-transparent border-0 outline-transparent line-clamp-2 text-n-slate-12 underline-offset-2 hover:underline focus-visible:underline"
        @click="emit('answer', gap)"
      >
        {{ gap.question }}
      </button>
      <span class="text-xs text-n-slate-11 truncate">
        {{ reasonLabel }}
      </span>
      <div class="flex sm:hidden items-center gap-2 mt-0.5">
        <span
          class="inline-flex items-center gap-1 rounded-full bg-n-amber-3 px-1.5 py-0.5 text-[11px] font-medium text-n-amber-11 dark:bg-n-amber-3/20"
        >
          <Icon icon="i-lucide-messages-square" class="size-3" />
          {{
            $t('CAPTAIN.KNOWLEDGE_GAPS.CONVERSATIONS', {
              count: gap.occurrences_count,
            })
          }}
        </span>
      </div>
    </div>
    <div class="hidden sm:flex items-center w-36 shrink-0">
      <span
        class="inline-flex items-center gap-1.5 rounded-full bg-n-amber-3 px-2 py-0.5 text-xs font-medium text-n-amber-11 dark:bg-n-amber-3/20"
      >
        <Icon icon="i-lucide-messages-square" class="size-3" />
        {{
          $t('CAPTAIN.KNOWLEDGE_GAPS.CONVERSATIONS', {
            count: gap.occurrences_count,
          })
        }}
      </span>
    </div>
    <div
      class="hidden md:flex items-center w-28 shrink-0 text-xs text-n-slate-10"
    >
      <span
        v-tooltip.top="{
          content: exactTimestamp(gap.last_seen_at),
          delay: { show: 500, hide: 0 },
        }"
      >
        {{ lastSeen }}
      </span>
    </div>
    <div class="flex items-center justify-end sm:w-44 shrink-0 gap-1.5">
      <Button
        type="button"
        :label="$t('CAPTAIN.KNOWLEDGE_GAPS.DISMISS')"
        size="xs"
        variant="ghost"
        color="slate"
        class="hidden sm:inline-flex"
        :disabled="isLoading"
        @click="emit('dismiss', gap)"
      />
      <Button
        type="button"
        :label="$t('CAPTAIN.KNOWLEDGE_GAPS.ADD_ANSWER')"
        icon="i-lucide-plus"
        size="xs"
        :is-loading="isLoading"
        :disabled="isLoading"
        @click="emit('answer', gap)"
      />
    </div>
  </div>
</template>

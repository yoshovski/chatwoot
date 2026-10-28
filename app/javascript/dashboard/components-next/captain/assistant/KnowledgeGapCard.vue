<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { useExactTimestamp } from 'shared/composables/useExactTimestamp';

import Button from 'dashboard/components-next/button/Button.vue';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
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
  <CardLayout>
    <div
      class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between"
    >
      <div class="flex min-w-0 flex-col gap-1.5">
        <h3 class="text-sm font-medium leading-5 text-n-slate-12 break-words">
          {{ gap.question }}
        </h3>
        <div
          class="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-n-slate-10"
        >
          <span
            class="inline-flex items-center gap-1.5 rounded-full bg-n-amber-3 px-2 py-0.5 font-medium text-n-amber-11"
          >
            <Icon icon="i-lucide-messages-square" class="size-3.5" />
            {{
              $t('CAPTAIN.KNOWLEDGE_GAPS.CONVERSATIONS', {
                count: gap.occurrences_count,
              })
            }}
          </span>
          <span
            v-tooltip.top="{
              content: exactTimestamp(gap.last_seen_at),
              delay: { show: 500, hide: 0 },
            }"
            class="inline-flex items-center gap-1.5"
          >
            <Icon icon="i-lucide-clock-3" class="size-3.5" />
            {{ $t('CAPTAIN.KNOWLEDGE_GAPS.LAST_SEEN', { time: lastSeen }) }}
          </span>
          <span class="inline-flex items-center gap-1.5">
            <Icon icon="i-lucide-circle-help" class="size-3.5" />
            {{ reasonLabel }}
          </span>
        </div>
      </div>

      <div class="flex shrink-0 items-center gap-2">
        <Button
          :label="$t('CAPTAIN.KNOWLEDGE_GAPS.DISMISS')"
          size="sm"
          variant="ghost"
          color="slate"
          :disabled="isLoading"
          @click="emit('dismiss', gap)"
        />
        <Button
          :label="$t('CAPTAIN.KNOWLEDGE_GAPS.ADD_ANSWER')"
          icon="i-lucide-plus"
          size="sm"
          :is-loading="isLoading"
          :disabled="isLoading"
          @click="emit('answer', gap)"
        />
      </div>
    </div>
  </CardLayout>
</template>

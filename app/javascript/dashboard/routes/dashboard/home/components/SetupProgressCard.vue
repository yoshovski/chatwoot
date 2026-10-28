<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import HomeCard from './HomeCard.vue';

const props = defineProps({
  progress: { type: Object, required: true },
  stepRoute: { type: Function, required: true },
});

const emit = defineEmits(['skip', 'unskip']);

const { t } = useI18n();

const STEP_TEXT = {
  knowledge: [
    'HOME.SETUP.STEPS.KNOWLEDGE.TITLE',
    'HOME.SETUP.STEPS.KNOWLEDGE.HINT',
  ],
  test_agent: [
    'HOME.SETUP.STEPS.TEST_AGENT.TITLE',
    'HOME.SETUP.STEPS.TEST_AGENT.HINT',
  ],
  agent_inbox: [
    'HOME.SETUP.STEPS.AGENT_INBOX.TITLE',
    'HOME.SETUP.STEPS.AGENT_INBOX.HINT',
  ],
  chat_widget: [
    'HOME.SETUP.STEPS.CHAT_WIDGET.TITLE',
    'HOME.SETUP.STEPS.CHAT_WIDGET.HINT',
  ],
  mailbox: ['HOME.SETUP.STEPS.MAILBOX.TITLE', 'HOME.SETUP.STEPS.MAILBOX.HINT'],
  teammate: [
    'HOME.SETUP.STEPS.TEAMMATE.TITLE',
    'HOME.SETUP.STEPS.TEAMMATE.HINT',
  ],
};
const stepTitle = key => t(STEP_TEXT[key][0]);
const stepHint = key => t(STEP_TEXT[key][1]);
const isOpen = step => !step.done && !step.skipped;
const stepIcon = step => {
  if (step.done) return 'i-lucide-circle-check';
  if (step.skipped) return 'i-lucide-circle-minus';
  return 'i-lucide-circle-dashed';
};

const percent = computed(() =>
  Math.round((props.progress.doneCount / props.progress.total) * 100)
);
</script>

<template>
  <HomeCard :title="$t('HOME.SETUP.TITLE')">
    <div class="flex flex-col gap-2">
      <div class="flex items-baseline justify-between gap-2">
        <span class="text-sm text-n-slate-11">
          {{
            $t('HOME.SETUP.PROGRESS', {
              done: progress.doneCount,
              total: progress.total,
            })
          }}
        </span>
        <span class="text-xs tabular-nums text-n-slate-10">
          {{ percent }}%
        </span>
      </div>
      <div class="h-1.5 w-full overflow-hidden rounded-full bg-n-alpha-2">
        <div
          class="h-full rounded-full bg-n-brand transition-all duration-300"
          :style="{ width: `${percent}%` }"
        />
      </div>
    </div>
    <ul class="flex flex-col divide-y divide-n-weak">
      <li
        v-for="step in progress.steps"
        :key="step.key"
        class="flex items-center justify-between gap-3 py-2.5 first:pt-0 last:pb-0"
      >
        <div class="flex min-w-0 items-start gap-2.5">
          <Icon
            :icon="stepIcon(step)"
            class="mt-0.5 size-4 shrink-0"
            :class="step.done ? 'text-n-teal-10' : 'text-n-slate-10'"
          />
          <div class="flex min-w-0 flex-col">
            <span
              class="text-sm font-medium"
              :class="isOpen(step) ? 'text-n-slate-12' : 'text-n-slate-11'"
            >
              {{ stepTitle(step.key) }}
            </span>
            <span v-if="isOpen(step)" class="text-xs text-n-slate-11">
              {{ stepHint(step.key) }}
            </span>
          </div>
        </div>
        <span v-if="step.done" class="shrink-0 text-xs text-n-slate-10">
          {{ $t('HOME.SETUP.DONE') }}
        </span>
        <div v-else-if="step.skipped" class="flex shrink-0 items-center gap-2">
          <span class="text-xs text-n-slate-10">
            {{ $t('HOME.SETUP.SKIPPED') }}
          </span>
          <Button
            :label="$t('HOME.SETUP.UNDO')"
            size="xs"
            variant="ghost"
            color="slate"
            @click="emit('unskip', step.key)"
          />
        </div>
        <div v-else class="flex shrink-0 items-center gap-1">
          <Button
            :label="$t('HOME.SETUP.SKIP')"
            size="xs"
            variant="ghost"
            color="slate"
            @click="emit('skip', step.key)"
          />
          <router-link :to="stepRoute(step)">
            <Button :label="$t('HOME.SETUP.GO')" size="xs" variant="faded" />
          </router-link>
        </div>
      </li>
    </ul>
  </HomeCard>
</template>

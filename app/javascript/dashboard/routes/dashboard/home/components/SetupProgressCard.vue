<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';
import Stepper from 'dashboard/components-next/kit/Stepper.vue';
import UsageMeter from 'dashboard/components-next/kit/UsageMeter.vue';

const props = defineProps({
  progress: { type: Object, required: true },
  stepRoute: { type: Function, required: true },
});

const emit = defineEmits(['skip', 'unskip']);

const { t } = useI18n();

const stepText = () => ({
  knowledge: {
    title: t('HOME.SETUP.STEPS.KNOWLEDGE.TITLE'),
    hint: t('HOME.SETUP.STEPS.KNOWLEDGE.HINT'),
  },
  test_agent: {
    title: t('HOME.SETUP.STEPS.TEST_AGENT.TITLE'),
    hint: t('HOME.SETUP.STEPS.TEST_AGENT.HINT'),
  },
  agent_inbox: {
    title: t('HOME.SETUP.STEPS.AGENT_INBOX.TITLE'),
    hint: t('HOME.SETUP.STEPS.AGENT_INBOX.HINT'),
  },
  chat_widget: {
    title: t('HOME.SETUP.STEPS.CHAT_WIDGET.TITLE'),
    hint: t('HOME.SETUP.STEPS.CHAT_WIDGET.HINT'),
  },
  mailbox: {
    title: t('HOME.SETUP.STEPS.MAILBOX.TITLE'),
    hint: t('HOME.SETUP.STEPS.MAILBOX.HINT'),
  },
  teammate: {
    title: t('HOME.SETUP.STEPS.TEAMMATE.TITLE'),
    hint: t('HOME.SETUP.STEPS.TEAMMATE.HINT'),
  },
});

const stepState = step => {
  if (step.done) return 'done';
  if (step.skipped) return 'skipped';
  return 'open';
};
const steps = computed(() => {
  const text = stepText();
  return props.progress.steps.map(step => ({
    ...step,
    ...text[step.key],
    state: stepState(step),
  }));
});
const percent = computed(() =>
  Math.round((props.progress.doneCount / props.progress.total) * 100)
);
</script>

<template>
  <SectionCard :title="$t('HOME.SETUP.TITLE')">
    <UsageMeter
      :label="
        $t('HOME.SETUP.PROGRESS', {
          done: progress.doneCount,
          total: progress.total,
        })
      "
      :used="progress.doneCount"
      :limit="progress.total"
      :value-label="`${percent}%`"
    />
    <Stepper :steps="steps">
      <template #actions="{ step }">
        <span v-if="step.state === 'done'" class="text-xs text-n-slate-10">
          {{ $t('HOME.SETUP.DONE') }}
        </span>
        <template v-else-if="step.state === 'skipped'">
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
        </template>
        <template v-else>
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
        </template>
      </template>
    </Stepper>
  </SectionCard>
</template>

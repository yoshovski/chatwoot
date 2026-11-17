<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';
import Stepper from 'dashboard/components-next/kit/Stepper.vue';
import UsageMeter from 'dashboard/components-next/kit/UsageMeter.vue';
import SetupProgressBar from './SetupProgressBar.vue';
import { setupStepText } from '../homeSetup';

const props = defineProps({
  progress: { type: Object, required: true },
  stepRoute: { type: Function, required: true },
  grouped: { type: Boolean, default: false },
});

const emit = defineEmits(['skip', 'unskip']);

const { t } = useI18n();

const stepState = step => {
  if (step.done) return 'done';
  if (step.skipped) return 'skipped';
  return 'open';
};
const steps = computed(() => {
  const text = setupStepText(t);
  return props.progress.steps.map(step => ({
    ...step,
    ...text[step.key],
    state: stepState(step),
  }));
});
const percent = computed(() =>
  Math.round((props.progress.doneCount / props.progress.total) * 100)
);
const groups = computed(() => {
  if (!props.grouped) return [{ key: 'all', steps: steps.value }];
  return [
    {
      key: 'ai',
      title: t('HOME.GETTING_STARTED.AI'),
      steps: steps.value.slice(0, 3),
    },
    {
      key: 'channels',
      title: t('HOME.GETTING_STARTED.CHANNELS'),
      steps: steps.value.slice(3, 5),
    },
    {
      key: 'team',
      title: t('HOME.GETTING_STARTED.TEAM'),
      steps: steps.value.slice(5),
    },
  ];
});
</script>

<template>
  <SectionCard
    :title="
      grouped ? t('HOME.GETTING_STARTED.FIRST_STEPS') : t('HOME.SETUP.TITLE')
    "
  >
    <div v-if="grouped" class="flex flex-col gap-2">
      <p class="m-0 flex justify-between gap-2 text-sm text-n-slate-11">
        {{
          $t('HOME.SETUP.PROGRESS', {
            done: progress.doneCount,
            total: progress.total,
          })
        }}
        <span class="font-medium tabular-nums">{{ `${percent}%` }}</span>
      </p>
      <SetupProgressBar :done="progress.doneCount" :total="progress.total" />
    </div>
    <UsageMeter
      v-else
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
    <section
      v-for="group in groups"
      :key="group.key"
      :class="{ 'border-t border-n-weak pt-4': grouped }"
    >
      <h3
        v-if="grouped"
        class="mb-3 mt-0 text-sm font-semibold text-n-slate-12"
      >
        {{ group.title }}
      </h3>
      <Stepper :steps="group.steps">
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
            <RouterLink
              :to="stepRoute(step)"
              class="inline-flex min-h-8 items-center rounded-md bg-n-blue-3 px-2.5 text-xs font-medium text-n-blue-11 hover:bg-n-blue-4"
            >
              {{ $t('HOME.SETUP.GO') }}
            </RouterLink>
          </template>
        </template>
      </Stepper>
    </section>
  </SectionCard>
</template>

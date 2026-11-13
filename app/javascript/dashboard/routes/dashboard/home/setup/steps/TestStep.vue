<script setup>
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import LearnedBanner from '../LearnedBanner.vue';
import StepIntro from './StepIntro.vue';

// Meet your agent: what it has learned so far and the starter questions from the instant agent. The chat itself is
// the widget next to the step.
defineProps({
  guided: { type: Object, required: true },
});

defineEmits(['open', 'ask']);
</script>

<template>
  <div class="flex flex-col gap-6">
    <StepIntro
      :title="$t('HOME.GUIDED.TEST.TITLE')"
      :description="$t('HOME.GUIDED.TEST.DESCRIPTION')"
    />
    <template v-if="guided.assistantId">
      <div
        class="rounded-card bg-n-solid-2 p-5 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
      >
        <LearnedBanner
          :learned="guided.learned"
          :total="guided.total"
          :reading="guided.isLearning || guided.isImporting"
        />
      </div>
      <div v-if="guided.starterQuestions.length" class="flex flex-col gap-2">
        <p class="mb-0 text-sm font-medium text-n-slate-12">
          {{ $t('HOME.GUIDED.TEST.TRY') }}
        </p>
        <div class="flex flex-wrap gap-2">
          <Button
            v-for="question in guided.starterQuestions"
            :key="question"
            :label="question"
            size="sm"
            variant="faded"
            class="!h-auto min-h-8 whitespace-normal py-1.5 text-start"
            @click="$emit('ask', question)"
          />
        </div>
      </div>
    </template>
    <div
      v-else
      class="flex flex-col items-center gap-3 rounded-card bg-n-alpha-1 px-4 py-10 text-center"
    >
      <Icon icon="i-lucide-message-circle" class="size-5 text-n-slate-10" />
      <p class="mb-0 max-w-sm text-sm text-n-slate-11">
        {{ $t('HOME.GUIDED.TEST.NO_AGENT') }}
      </p>
      <Button
        :label="$t('HOME.SETUP.STEPS.KNOWLEDGE.TITLE')"
        size="sm"
        variant="faded"
        color="slate"
        @click="$emit('open', 'knowledge')"
      />
    </div>
  </div>
</template>

<script setup>
import AssistantPlayground from 'dashboard/components-next/captain/assistant/AssistantPlayground.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import StepIntro from './StepIntro.vue';

defineProps({
  guided: { type: Object, required: true },
});

defineEmits(['open']);
</script>

<template>
  <div class="flex flex-1 flex-col gap-4">
    <StepIntro
      :title="$t('HOME.GUIDED.TEST.TITLE')"
      :description="$t('HOME.GUIDED.TEST.DESCRIPTION')"
    />
    <div
      v-if="guided.assistantId"
      class="flex h-[32rem] max-h-[70vh] min-h-[22rem] flex-col overflow-hidden rounded-lg outline outline-1 -outline-offset-1 outline-n-weak"
    >
      <AssistantPlayground
        :assistant-id="guided.assistantId"
        class="bg-n-surface-1"
      />
    </div>
    <div
      v-else
      class="flex flex-col items-center gap-3 rounded-lg bg-n-alpha-1 px-4 py-10 text-center"
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

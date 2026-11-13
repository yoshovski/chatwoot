<script setup>
import { computed } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import StepIntro from './StepIntro.vue';

const props = defineProps({
  guided: { type: Object, required: true },
});

defineEmits(['open']);

const state = computed(() => props.guided.state || {});
const readiness = computed(() => state.value.readiness);
const inbox = computed(() => state.value.widget_inbox);
const canTurnOn = computed(() =>
  ['ready', 'importing'].includes(readiness.value)
);

// Turning on is the setup's primary button; without knowledge the step points back to the website.
const knowledgeRow = computed(() => {
  if (readiness.value === 'ready')
    return {
      icon: 'i-lucide-circle-check',
      tone: 'text-n-teal-10',
      label: 'HOME.GUIDED.LIVE.KNOWLEDGE_READY',
    };
  if (readiness.value === 'importing')
    return {
      icon: 'i-lucide-loader-circle',
      tone: 'text-n-amber-10',
      label: 'HOME.GUIDED.LIVE.KNOWLEDGE_IMPORTING',
    };
  return {
    icon: 'i-lucide-circle-x',
    tone: 'text-n-ruby-10',
    label: 'HOME.GUIDED.LIVE.NO_KNOWLEDGE',
  };
});
</script>

<template>
  <div class="flex flex-col gap-6">
    <StepIntro
      :title="$t('HOME.GUIDED.LIVE.TITLE')"
      :description="$t('HOME.GUIDED.LIVE.DESCRIPTION')"
    />

    <div
      v-if="state.agent_live"
      class="flex items-start gap-3 rounded-lg bg-n-teal-2 p-4"
      role="status"
    >
      <Icon icon="i-lucide-badge-check" class="mt-0.5 size-5 text-n-teal-10" />
      <div class="flex flex-col gap-0.5">
        <span class="text-sm font-medium text-n-slate-12">
          {{ $t('HOME.GUIDED.LIVE.ON_TITLE') }}
        </span>
        <span class="text-sm text-n-slate-11">
          {{ $t('HOME.GUIDED.LIVE.ON_BODY', { name: inbox?.name }) }}
        </span>
      </div>
    </div>

    <template v-else>
      <ul class="flex flex-col gap-3">
        <li class="flex items-start gap-2.5 text-sm text-n-slate-12">
          <Icon
            :icon="knowledgeRow.icon"
            class="mt-0.5 size-4 shrink-0"
            :class="knowledgeRow.tone"
          />
          {{ $t(knowledgeRow.label) }}
        </li>
        <li class="flex items-start gap-2.5 text-sm text-n-slate-12">
          <Icon
            :icon="inbox ? 'i-lucide-circle-check' : 'i-lucide-circle-plus'"
            class="mt-0.5 size-4 shrink-0"
            :class="inbox ? 'text-n-teal-10' : 'text-n-slate-10'"
          />
          {{
            inbox
              ? $t('HOME.GUIDED.LIVE.INBOX_READY', { name: inbox.name })
              : $t('HOME.GUIDED.LIVE.INBOX_NEW')
          }}
        </li>
      </ul>
      <Button
        v-if="!canTurnOn"
        class="self-start"
        :label="$t('HOME.SETUP.STEPS.KNOWLEDGE.TITLE')"
        variant="faded"
        color="slate"
        size="sm"
        @click="$emit('open', 'knowledge')"
      />
    </template>
  </div>
</template>

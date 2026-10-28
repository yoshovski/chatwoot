<script setup>
import { computed, ref } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import StepIntro from './StepIntro.vue';

const props = defineProps({
  guided: { type: Object, required: true },
});

defineEmits(['open']);

const isTurningOn = ref(false);
const error = ref('');

const state = computed(() => props.guided.state || {});
const readiness = computed(() => state.value.readiness);
const inbox = computed(() => state.value.widget_inbox);
const canTurnOn = computed(() =>
  ['ready', 'importing'].includes(readiness.value)
);

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

const turnOn = async () => {
  error.value = '';
  isTurningOn.value = true;
  const result = await props.guided.goLive();
  isTurningOn.value = false;
  if (!result.ok) error.value = result.error;
};
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
      <div class="flex flex-wrap items-center gap-3">
        <Button
          v-if="canTurnOn"
          :label="$t('HOME.GUIDED.LIVE.TURN_ON')"
          icon="i-lucide-power"
          :is-loading="isTurningOn"
          @click="turnOn"
        />
        <Button
          v-else
          :label="$t('HOME.SETUP.STEPS.KNOWLEDGE.TITLE')"
          variant="faded"
          color="slate"
          size="sm"
          @click="$emit('open', 'knowledge')"
        />
      </div>
      <p v-if="error" role="alert" class="mb-0 text-sm text-n-ruby-11">
        {{ error }}
      </p>
    </template>
  </div>
</template>

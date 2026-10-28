<script setup>
import { computed, nextTick, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import SidePanel from 'dashboard/components-next/side-panel/SidePanel.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import StepCard from './StepCard.vue';
import TestPanel from './TestPanel.vue';
import OutputsTable from './OutputsTable.vue';
import { variablesBefore } from './actionForm';

// Edits one step next to a test run of it, so a response field can be saved as an output with one click.
const props = defineProps({
  index: { type: Number, required: true },
  toolId: { type: Number, default: null },
  agentName: { type: String, required: true },
  errors: { type: Object, default: () => ({}) },
});

const emit = defineEmits(['close', 'move', 'remove']);
const form = defineModel('form', { type: Object, required: true });
const result = defineModel('result', { type: Object, default: null });
const { t } = useI18n();

const panel = ref(null);
const focusedOutputKey = ref('');

const step = computed(() => form.value.steps[props.index]);
const title = computed(() =>
  t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.PANEL_TITLE', {
    number: props.index + 1,
    type:
      step.value.type === 'request'
        ? t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.REQUEST')
        : t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.VERIFY'),
  })
);

const addOutput = output => {
  form.value.outputs.push(output);
  focusedOutputKey.value = output.key;
};
const focusOutput = async key => {
  focusedOutputKey.value = key;
  await nextTick();
  document
    .querySelector(`[data-output-key="${key}"]`)
    ?.scrollIntoView({ behavior: 'smooth', block: 'center' });
};

// The step is removed once the panel has closed, so the panel never renders a missing step.
const isRemoving = ref(false);
const remove = () => {
  isRemoving.value = true;
  panel.value.close();
};
const onClosed = () => {
  if (isRemoving.value) emit('remove');
  emit('close');
};

onMounted(() => panel.value.open());
</script>

<template>
  <SidePanel ref="panel" :title="title" width="5xl" @after-leave="onClosed">
    <template #header-actions>
      <Button
        type="button"
        size="sm"
        variant="ghost"
        color="slate"
        icon="i-lucide-arrow-up"
        :disabled="index === 0"
        :aria-label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.MOVE_UP')"
        @click="emit('move', -1)"
      />
      <Button
        type="button"
        size="sm"
        variant="ghost"
        color="slate"
        icon="i-lucide-arrow-down"
        :disabled="index === form.steps.length - 1"
        :aria-label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.MOVE_DOWN')"
        @click="emit('move', 1)"
      />
      <Button
        type="button"
        size="sm"
        variant="ghost"
        color="ruby"
        icon="i-lucide-trash"
        :aria-label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.REMOVE')"
        @click="remove"
      />
    </template>

    <div class="grid gap-8 lg:grid-cols-2">
      <StepCard
        v-model:step="form.steps[index]"
        :variables="variablesBefore(form, index)"
        :errors="errors[`steps.${step.key}`] || []"
      />
      <div
        class="flex flex-col gap-6 lg:ps-8 lg:border-s lg:border-n-weak min-w-0"
      >
        <section class="flex flex-col gap-3">
          <h4 class="mb-0 text-sm font-medium text-n-slate-12">
            {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.TITLE') }}
          </h4>
          <TestPanel
            v-model:form="form"
            v-model:result="result"
            :step-key="step.key"
            :tool-id="toolId"
            @add-output="addOutput"
            @focus-output="focusOutput"
          />
        </section>
        <section v-if="step.type === 'request'" class="flex flex-col gap-3">
          <h4 class="mb-0 text-sm font-medium text-n-slate-12">
            {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.OUTPUTS.TITLE') }}
          </h4>
          <OutputsTable
            v-model:outputs="form.outputs"
            :step-key="step.key"
            :agent-name="agentName"
            :focused-key="focusedOutputKey"
            :errors="errors"
          />
        </section>
      </div>
    </div>

    <template #footer>
      <div class="flex justify-end">
        <Button
          type="button"
          size="sm"
          :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.DONE')"
          @click="panel.close()"
        />
      </div>
    </template>
  </SidePanel>
</template>

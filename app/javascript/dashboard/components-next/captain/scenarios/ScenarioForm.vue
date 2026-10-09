<script setup>
import { computed, reactive } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Editor from 'dashboard/components-next/Editor/Editor.vue';
import ToolChip from './ToolChip.vue';
import { getToolIdsFromInstruction, unlinkTool } from './scenarioTools';

const title = defineModel('title', { type: String, default: '' });
const description = defineModel('description', { type: String, default: '' });
const instruction = defineModel('instruction', { type: String, default: '' });

const DESCRIPTION_MAX_LENGTH = 500;
// Saved steps come back as plain tool:// links; show them like the chips the palette inserts.
const TOOL_LINK_CHIP_CLASS =
  '[&_a[href^="tool://"]]:rounded-full [&_a[href^="tool://"]]:bg-n-iris-3 [&_a[href^="tool://"]]:px-1.5 [&_a[href^="tool://"]]:py-0.5 [&_a[href^="tool://"]]:text-n-iris-11 [&_a[href^="tool://"]]:no-underline [&_a[href^="tool://"]]:font-medium';

const { t } = useI18n();

const v$ = useVuelidate(
  {
    title: { required },
    description: { required },
    instruction: { required },
  },
  reactive({ title, description, instruction })
);

const errorFor = (field, key) =>
  v$.value[field].$error ? t(`CAPTAIN.ASSISTANTS.SCENARIOS.FORM.${key}.ERROR`) : '';

const titleError = computed(() => errorFor('title', 'TITLE'));
const descriptionError = computed(() =>
  errorFor('description', 'DESCRIPTION')
);
const instructionError = computed(() =>
  errorFor('instruction', 'INSTRUCTION')
);

const linkedToolIds = computed(() =>
  getToolIdsFromInstruction(instruction.value)
);

const removeTool = toolId => {
  instruction.value = unlinkTool(instruction.value, toolId);
};

const validate = () => {
  v$.value.$touch();
  return !v$.value.$invalid;
};

const reset = () => v$.value.$reset();

defineExpose({ validate, reset });
</script>

<template>
  <div class="flex flex-col gap-4 w-full">
    <Input
      v-model="title"
      :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.FORM.TITLE.LABEL')"
      :placeholder="t('CAPTAIN.ASSISTANTS.SCENARIOS.FORM.TITLE.PLACEHOLDER')"
      :message="titleError"
      :message-type="titleError ? 'error' : 'info'"
    />

    <TextArea
      v-model="description"
      :max-length="DESCRIPTION_MAX_LENGTH"
      :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.FORM.DESCRIPTION.LABEL')"
      :placeholder="
        t('CAPTAIN.ASSISTANTS.SCENARIOS.FORM.DESCRIPTION.PLACEHOLDER')
      "
      :message="
        descriptionError || t('CAPTAIN.ASSISTANTS.SCENARIOS.FORM.DESCRIPTION.HELP')
      "
      :message-type="descriptionError ? 'error' : 'info'"
      show-character-count
      auto-height
    />

    <div class="flex flex-col gap-2">
      <Editor
        v-model="instruction"
        :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.FORM.INSTRUCTION.LABEL')"
        :placeholder="
          t('CAPTAIN.ASSISTANTS.SCENARIOS.FORM.INSTRUCTION.PLACEHOLDER')
        "
        :message="
          instructionError ||
          t('CAPTAIN.ASSISTANTS.SCENARIOS.FORM.INSTRUCTION.HELP')
        "
        :message-type="instructionError ? 'error' : 'info'"
        :show-character-count="false"
        :class="TOOL_LINK_CHIP_CLASS"
        enable-captain-tools
        show-tool-palette
      />

      <div
        class="flex flex-wrap items-center gap-1.5"
        data-test="scenario-form-tools"
      >
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.FORM.TOOLS.LABEL') }}
        </span>
        <template v-if="linkedToolIds.length">
          <ToolChip
            v-for="toolId in linkedToolIds"
            :key="toolId"
            :tool-id="toolId"
            removable
            @remove="removeTool(toolId)"
          />
        </template>
        <span v-else class="text-xs text-n-slate-10">
          {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.FORM.TOOLS.NONE') }}
        </span>
      </div>
    </div>
  </div>
</template>

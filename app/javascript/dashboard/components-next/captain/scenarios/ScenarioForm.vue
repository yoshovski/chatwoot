<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useConfig } from 'dashboard/composables/useConfig';
import Select from 'dashboard/components-next/select/Select.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import ActionInstructionEditor from './ActionInstructionEditor.vue';
import ToolChip from './ToolChip.vue';
import {
  getToolIdsFromInstruction,
  getToolTitlesFromInstruction,
  unlinkTool,
} from './scenarioTools';
import { parseToolReference } from './builtInActions';

const props = defineProps({
  replyLocales: { type: Array, default: null },
});

const localizedReplyCopy = defineModel('localizedReplyCopy', {
  type: Object,
  default: () => ({}),
});
const title = defineModel('title', { type: String, default: '' });
const description = defineModel('description', { type: String, default: '' });
const instruction = defineModel('instruction', { type: String, default: '' });

const DESCRIPTION_MAX_LENGTH = 500;

const { t } = useI18n();
const { enabledLanguages } = useConfig();
const selectedLocale = ref('');
const localeOptions = computed(() =>
  (enabledLanguages || [])
    .filter(
      ({ iso_639_1_code: code }) =>
        !props.replyLocales?.length || props.replyLocales.includes(code)
    )
    .map(({ iso_639_1_code: value, name: label }) => ({ value, label }))
);
const replyLocale = computed(() =>
  localeOptions.value.some(({ value }) => value === selectedLocale.value)
    ? selectedLocale.value
    : localeOptions.value[0]?.value
);
const updateReplyCopy = text => {
  const copy = { ...localizedReplyCopy.value };
  if (text.trim()) copy[replyLocale.value] = text.trim();
  else delete copy[replyLocale.value];
  localizedReplyCopy.value = copy;
};

const v$ = useVuelidate(
  {
    title: { required },
    description: { required },
    instruction: { required },
  },
  reactive({ title, description, instruction })
);

const errorFor = (field, key) =>
  v$.value[field].$error
    ? t(`CAPTAIN.ASSISTANTS.SCENARIOS.FORM.${key}.ERROR`)
    : '';

const titleError = computed(() => errorFor('title', 'TITLE'));
const descriptionError = computed(() => errorFor('description', 'DESCRIPTION'));
const instructionError = computed(() => errorFor('instruction', 'INSTRUCTION'));

const linkedToolIds = computed(() =>
  getToolIdsFromInstruction(instruction.value)
);
const linkedToolTitles = computed(() =>
  getToolTitlesFromInstruction(instruction.value)
);

// A built-in action with fixed values shows its own text ("Save Company size").
const chipLabel = reference =>
  reference.includes('?') ? linkedToolTitles.value[reference] : '';

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
        descriptionError ||
        t('CAPTAIN.ASSISTANTS.SCENARIOS.FORM.DESCRIPTION.HELP')
      "
      :message-type="descriptionError ? 'error' : 'info'"
      show-character-count
      auto-height
    />

    <div class="flex flex-col gap-2">
      <ActionInstructionEditor
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
            :tool-id="parseToolReference(toolId).id"
            :label="chipLabel(toolId)"
            removable
            @remove="removeTool(toolId)"
          />
        </template>
        <span v-else class="text-xs text-n-slate-10">
          {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.FORM.TOOLS.NONE') }}
        </span>
      </div>
    </div>
    <details v-if="replyLocales && localeOptions.length">
      <summary class="cursor-pointer text-sm font-medium text-n-slate-12">
        {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.FORM.REPLY_COPY.TITLE') }}
      </summary>
      <div class="mt-2 flex flex-col gap-2">
        <Select
          :model-value="replyLocale"
          :options="localeOptions"
          :aria-label="t('CAPTAIN.AGENT_UX.STYLE.LANGUAGES.MESSAGES.LANGUAGE')"
          @update:model-value="selectedLocale = $event"
        />
        <TextArea
          :model-value="localizedReplyCopy[replyLocale] || ''"
          :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.FORM.REPLY_COPY.TITLE')"
          :message="t('CAPTAIN.ASSISTANTS.SCENARIOS.FORM.REPLY_COPY.HELP')"
          :max-length="2000"
          @update:model-value="updateReplyCopy"
        />
      </div>
    </details>
  </div>
</template>

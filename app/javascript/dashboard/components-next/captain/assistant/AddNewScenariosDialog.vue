<script setup>
import { computed, reactive, ref, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import CaptainScenarios from 'dashboard/api/captain/scenarios';
import TemplateCard from '../scenarios/TemplateCard.vue';
import ScenarioForm from '../scenarios/ScenarioForm.vue';
import { SCENARIO_TEMPLATES } from '../scenarios/scenarioTemplates';

const props = defineProps({
  assistantId: {
    type: [Number, String],
    default: null,
  },
  tools: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['add', 'useTemplate']);

const { t } = useI18n();
const route = useRoute();
const dialogRef = ref(null);
const promptInputRef = ref(null);
const HINT_EMOJI = '💡';

const currentAssistantId = computed(
  () => props.assistantId || Number(route.params.assistantId)
);

// Tab choices: 'describe', 'template', 'manual'
const activeChoice = ref('describe');

const choices = computed(() => [
  {
    key: 'describe',
    label: t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.BUILDER.CHOICES.DESCRIBE'),
  },
  {
    key: 'template',
    label: t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.BUILDER.CHOICES.TEMPLATE'),
  },
  {
    key: 'manual',
    label: t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.BUILDER.CHOICES.MANUAL'),
  },
]);

// 1. Describe it state
const describePrompt = ref('');
const isGenerating = ref(false);
const draftResult = ref(null);

const examplePrompts = computed(() => [
  t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.BUILDER.DESCRIBE.EXAMPLE_1'),
  t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.BUILDER.DESCRIBE.EXAMPLE_2'),
  t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.BUILDER.DESCRIBE.EXAMPLE_3'),
]);

const previewState = reactive({
  title: '',
  description: '',
  instruction: '',
  notes: [],
});

// 2. Manual form state
const manualState = reactive({
  title: '',
  description: '',
  instruction: '',
});

const previewFormRef = ref(null);
const manualFormRef = ref(null);

const open = () => {
  activeChoice.value = 'describe';
  draftResult.value = null;
  dialogRef.value?.open();
  nextTick(() => {
    promptInputRef.value?.$el?.focus?.();
  });
};

const close = () => {
  dialogRef.value?.close();
};

const setChoice = key => {
  activeChoice.value = key;
};

// Builder methods
const generateDraft = async () => {
  const promptText = describePrompt.value.trim();
  if (promptText.length < 10) return;

  isGenerating.value = true;
  try {
    const response = await CaptainScenarios.draft({
      assistantId: currentAssistantId.value,
      description: promptText,
    });

    const data = response.data || response;
    draftResult.value = data;
    previewState.title = data.title || '';
    previewState.description = data.description || '';
    previewState.instruction = data.instruction || '';
    previewState.notes = data.notes || [];
  } catch {
    useAlert(t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.BUILDER.DESCRIBE.ERROR'));
  } finally {
    isGenerating.value = false;
  }
};

const editPrompt = () => {
  draftResult.value = null;
};

const saveDraftScenario = () => {
  if (!previewFormRef.value.validate()) return;

  emit('add', {
    title: previewState.title.trim(),
    description: previewState.description.trim(),
    instruction: previewState.instruction.trim(),
  });
  close();
};

// Template selection method
const onUseTemplate = template => {
  close();
  emit('useTemplate', template);
};

// Manual submit method
const onClickAddManual = async () => {
  if (!manualFormRef.value.validate()) return;

  await emit('add', {
    title: manualState.title.trim(),
    description: manualState.description.trim(),
    instruction: manualState.instruction.trim(),
  });

  manualState.title = '';
  manualState.description = '';
  manualState.instruction = '';
  manualFormRef.value.reset();
  close();
};

defineExpose({
  open,
  close,
  generateDraft,
  activeChoice,
  describePrompt,
  draftResult,
  previewState,
});
</script>

<template>
  <div class="inline-flex">
    <Button
      :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.CREATE')"
      sm
      slate
      class="flex-shrink-0"
      @click="open"
    />

    <Dialog
      ref="dialogRef"
      width="2xl"
      :title="t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.TITLE')"
      :show-cancel-button="false"
      :show-confirm-button="false"
      overflow-y-auto
    >
      <!-- Top Choices Segmented Navigation -->
      <div
        class="flex items-center gap-1 p-1 bg-n-alpha-1 rounded-xl border border-n-weak w-fit -mt-2 mb-2"
      >
        <button
          v-for="choice in choices"
          :key="choice.key"
          type="button"
          class="px-3.5 py-1.5 rounded-lg text-xs font-medium transition-all select-none"
          :class="[
            activeChoice === choice.key
              ? 'bg-n-solid-3 text-n-slate-12 shadow-sm font-semibold'
              : 'text-n-slate-11 hover:text-n-slate-12',
          ]"
          @click="setChoice(choice.key)"
        >
          {{ choice.label }}
        </button>
      </div>

      <!-- 1. DESCRIBE IT TAB -->
      <div v-if="activeChoice === 'describe'" class="flex flex-col gap-4 py-1">
        <!-- Skeleton Loading State -->
        <div
          v-if="isGenerating"
          class="flex flex-col gap-4 py-4 animate-pulse motion-reduce:animate-none"
        >
          <div class="flex items-center gap-2.5 text-sm text-n-slate-11">
            <span
              class="inline-block size-4 rounded-full border-2 border-n-brand border-t-transparent animate-spin motion-reduce:animate-none"
            />
            <span>
              {{
                t(
                  'CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.BUILDER.DESCRIBE.BUILDING'
                )
              }}
            </span>
          </div>
          <div class="h-10 w-2/3 rounded-lg bg-n-alpha-2" />
          <div class="h-20 w-full rounded-lg bg-n-alpha-2" />
          <div class="h-44 w-full rounded-lg bg-n-alpha-2" />
        </div>

        <!-- Prompt Input Form (before draft is generated) -->
        <div v-else-if="!draftResult" class="flex flex-col gap-4 min-h-[14rem]">
          <TextArea
            ref="promptInputRef"
            v-model="describePrompt"
            :label="
              t(
                'CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.BUILDER.DESCRIBE.PROMPT_LABEL'
              )
            "
            :placeholder="
              t(
                'CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.BUILDER.DESCRIBE.PROMPT_PLACEHOLDER'
              )
            "
            :rows="4"
          />

          <!-- Clickable Example Prompts -->
          <div class="flex flex-col gap-2">
            <span class="text-xs font-medium text-n-slate-11">
              {{
                t(
                  'CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.BUILDER.DESCRIBE.EXAMPLES_LABEL'
                )
              }}
            </span>
            <div class="flex flex-col gap-1.5">
              <button
                v-for="example in examplePrompts"
                :key="example"
                type="button"
                class="text-start px-3 py-2 rounded-lg text-xs bg-n-alpha-2 text-n-slate-12 border border-n-weak hover:bg-n-alpha-3 hover:border-n-slate-6 transition-colors"
                @click="describePrompt = example"
              >
                {{ `"${example}"` }}
              </button>
            </div>
          </div>
        </div>

        <!-- Preview Generated Scenario (after draft is generated) -->
        <div v-else class="flex flex-col gap-4">
          <!-- Optional notes from model -->
          <div
            v-if="previewState.notes?.length"
            class="flex flex-col gap-1.5 p-3 rounded-lg bg-n-alpha-1 border border-n-weak text-xs text-n-slate-11"
          >
            <div
              v-for="(note, idx) in previewState.notes"
              :key="idx"
              class="flex items-start gap-1.5"
            >
              <span aria-hidden="true">{{ HINT_EMOJI }}</span>
              <span>{{ note }}</span>
            </div>
          </div>

          <ScenarioForm
            ref="previewFormRef"
            v-model:title="previewState.title"
            v-model:description="previewState.description"
            v-model:instruction="previewState.instruction"
          />
        </div>
      </div>

      <!-- 2. START FROM A TEMPLATE TAB -->
      <div
        v-else-if="activeChoice === 'template'"
        class="grid grid-cols-1 md:grid-cols-2 gap-4 py-2 max-h-[32rem] overflow-y-auto pr-1"
      >
        <TemplateCard
          v-for="template in SCENARIO_TEMPLATES"
          :key="template.id"
          :template="template"
          :tools="tools"
          @use="onUseTemplate"
        />
      </div>

      <!-- 3. WRITE IT MYSELF TAB -->
      <div
        v-else-if="activeChoice === 'manual'"
        class="flex flex-col gap-4 py-1"
      >
        <ScenarioForm
          ref="manualFormRef"
          v-model:title="manualState.title"
          v-model:description="manualState.description"
          v-model:instruction="manualState.instruction"
        />
      </div>

      <!-- Footer Buttons -->
      <template #footer>
        <!-- Footer for Describe It (Before generation) -->
        <div
          v-if="activeChoice === 'describe' && !draftResult"
          class="flex items-center justify-end w-full gap-3 pt-4 border-t border-n-weak"
        >
          <Button
            variant="faded"
            color="slate"
            :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.FORM.CANCEL')"
            type="button"
            @click="close"
          />
          <Button
            :disabled="
              !describePrompt.trim() ||
              describePrompt.trim().length < 10 ||
              isGenerating
            "
            :is-loading="isGenerating"
            :label="
              t(
                'CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.BUILDER.DESCRIBE.BUILD_BUTTON'
              )
            "
            type="button"
            @click="generateDraft"
          />
        </div>

        <!-- Footer for Describe It (Preview mode) -->
        <div
          v-else-if="activeChoice === 'describe' && draftResult"
          class="flex items-center justify-between w-full pt-4 border-t border-n-weak"
        >
          <div class="flex items-center gap-2">
            <Button
              variant="faded"
              color="slate"
              :label="
                t(
                  'CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.BUILDER.DESCRIBE.EDIT_PROMPT'
                )
              "
              type="button"
              @click="editPrompt"
            />
            <Button
              variant="faded"
              color="slate"
              icon="i-lucide-refresh-cw"
              :is-loading="isGenerating"
              :label="
                t(
                  'CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.BUILDER.DESCRIBE.REGENERATE'
                )
              "
              type="button"
              @click="generateDraft"
            />
          </div>

          <div class="flex items-center gap-2">
            <Button
              variant="faded"
              color="slate"
              :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.FORM.CANCEL')"
              type="button"
              @click="close"
            />
            <Button
              :label="
                t(
                  'CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.BUILDER.DESCRIBE.ADD_SCENARIO'
                )
              "
              type="button"
              @click="saveDraftScenario"
            />
          </div>
        </div>

        <!-- Footer for Start From Template -->
        <div
          v-else-if="activeChoice === 'template'"
          class="flex items-center justify-end w-full pt-4 border-t border-n-weak"
        >
          <Button
            variant="faded"
            color="slate"
            :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.FORM.CANCEL')"
            type="button"
            @click="close"
          />
        </div>

        <!-- Footer for Write It Myself -->
        <div
          v-else-if="activeChoice === 'manual'"
          class="flex items-center justify-between w-full gap-3 pt-4 border-t border-n-weak"
        >
          <Button
            variant="faded"
            color="slate"
            :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.FORM.CANCEL')"
            class="w-full"
            type="button"
            @click="close"
          />
          <Button
            :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.FORM.CREATE')"
            class="w-full"
            type="button"
            @click="onClickAddManual"
          />
        </div>
      </template>
    </Dialog>
  </div>
</template>

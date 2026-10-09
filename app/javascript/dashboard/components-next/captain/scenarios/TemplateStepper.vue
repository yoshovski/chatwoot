<script setup>
import { ref, reactive, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ScenarioForm from './ScenarioForm.vue';
import {
  CUSTOM_ENTRY_MAX_LENGTH,
  MAX_CUSTOM_ENTRIES,
  allowlistEntryFor,
  buildFromTemplate,
  defaultAnswers,
  isLinkAllowed,
} from './scenarioTemplates';

const props = defineProps({
  template: {
    type: Object,
    required: true,
  },
  tools: {
    type: Array,
    default: () => [],
  },
  assistant: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['add', 'back']);

const LABEL_TITLE_REGEX = /^[\p{L}\p{N}_-]+$/u;
const LABEL_COLOR = '#1F93FF';
const MAX_LABEL_SUGGESTIONS = 8;

const { t, te } = useI18n();
const store = useStore();
const labels = useMapGetter('labels/getLabels');

const previewFormRef = ref(null);
const currentStep = ref(0);
const showAllowlistConfirm = ref(false);
const isSaving = ref(false);
const customEntry = ref('');

const answers = reactive(defaultAnswers(props.template));
const previewData = reactive({ title: '', description: '', instruction: '' });

const templateKey = `CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.${props.template.id.toUpperCase()}`;
const questions = props.template.questions;
const totalSteps = questions.length + 1;

const isPreviewStep = computed(() => currentStep.value === questions.length);
const currentQuestion = computed(() => questions[currentStep.value]);
const progressWidth = computed(
  () => `${((currentStep.value + 1) / totalSteps) * 100}%`
);

const questionText = (part, question = currentQuestion.value) => {
  const key = `${templateKey}.QUESTIONS.${question.key.toUpperCase()}.${part}`;
  return te(key) ? t(key) : '';
};
const fieldLabel = value =>
  t(`CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.FIELDS.${value.toUpperCase()}`);
const groupLabel = key =>
  t(`CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.GROUPS.${key.toUpperCase()}`);
const optionLabel = value =>
  t(`CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.OPTIONS.${value.toUpperCase()}`);

const isValidHttpsUrl = value => {
  try {
    return new URL(value).protocol === 'https:';
  } catch {
    return false;
  }
};

const questionError = computed(() => {
  const question = currentQuestion.value;
  const value = answers[question?.key];
  if (question?.type === 'url' && value && !isValidHttpsUrl(value)) {
    return t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.URL_ERROR');
  }
  if (question?.type === 'label' && value && !LABEL_TITLE_REGEX.test(value)) {
    return t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.LABEL_ERROR');
  }
  return '';
});

const canProceed = computed(() => {
  const question = currentQuestion.value;
  if (questionError.value) return false;
  if (!question.required) return true;
  const value = answers[question.key];
  return Array.isArray(value) ? value.length > 0 : Boolean(`${value}`.trim());
});

// Chips: predefined values are strings, custom entries { custom: true, label }.
const isSelected = (key, value) => answers[key].includes(value);
const toggleOption = (key, value) => {
  answers[key] = isSelected(key, value)
    ? answers[key].filter(item => item !== value)
    : [...answers[key], value];
};
const customEntries = key => answers[key].filter(item => item.custom);

const customEntryError = computed(() => {
  const label = customEntry.value.trim();
  if (!label) return '';
  const question = currentQuestion.value;
  const takenLabels = [
    ...question.groups.flatMap(group => group.options).map(fieldLabel),
    ...customEntries(question.key).map(item => item.label),
  ].map(item => item.toLowerCase());
  if (takenLabels.includes(label.toLowerCase())) {
    return t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.CUSTOM.DUPLICATE');
  }
  if (label.length < 2 || label.length > CUSTOM_ENTRY_MAX_LENGTH) {
    return t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.CUSTOM.LENGTH', {
      max: CUSTOM_ENTRY_MAX_LENGTH,
    });
  }
  return '';
});

const canAddCustom = computed(
  () =>
    customEntries(currentQuestion.value.key).length < MAX_CUSTOM_ENTRIES &&
    customEntry.value.trim() &&
    !customEntryError.value
);

const addCustomEntry = () => {
  if (!canAddCustom.value) return;
  const { key } = currentQuestion.value;
  answers[key] = [
    ...answers[key],
    { custom: true, label: customEntry.value.trim() },
  ];
  customEntry.value = '';
};

const removeCustomEntry = (key, entry) => {
  answers[key] = answers[key].filter(item => item !== entry);
};

// Label question
const labelExists = computed(() =>
  labels.value.some(label => label.title === answers.label)
);
const labelSuggestions = computed(() => {
  const query = (answers.label || '').toLowerCase();
  return labels.value
    .filter(label => label.title.includes(query))
    .slice(0, MAX_LABEL_SUGGESTIONS);
});
const normalizeLabel = () => {
  answers.label = answers.label.trim().toLowerCase().replace(/\s+/g, '-');
};

const goToNext = () => {
  if (currentStep.value === questions.length - 1) {
    Object.assign(
      previewData,
      buildFromTemplate(props.template, answers, props.tools)
    );
  }
  customEntry.value = '';
  currentStep.value += 1;
};

const goToBack = () => {
  if (showAllowlistConfirm.value) {
    showAllowlistConfirm.value = false;
  } else if (currentStep.value === 0) {
    emit('back');
  } else {
    customEntry.value = '';
    currentStep.value -= 1;
  }
};

const bookingHost = computed(() =>
  answers.booking_url ? new URL(answers.booking_url).host : ''
);

const needsAllowlistEntry = () =>
  Boolean(answers.booking_url) &&
  !isLinkAllowed(answers.booking_url, props.assistant.link_allowlist || []);

const addToAllowlist = () =>
  store.dispatch('captainAssistants/update', {
    id: props.assistant.id,
    config: {
      link_allowlist: [
        ...(props.assistant.link_allowlist || []),
        allowlistEntryFor(answers.booking_url),
      ],
    },
  });

const createMissingLabel = () =>
  store.dispatch('labels/create', {
    title: answers.label,
    color: LABEL_COLOR,
    description: '',
    show_on_sidebar: true,
  });

const finishSave = async ({ allowLink }) => {
  isSaving.value = true;
  try {
    if (allowLink) await addToAllowlist();
    if (answers.label && !labelExists.value) await createMissingLabel();
    emit('add', { ...previewData });
  } catch (error) {
    useAlert(
      error?.message ||
        t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.SAVE_ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

const saveScenario = () => {
  if (!previewFormRef.value.validate()) return;
  if (needsAllowlistEntry()) {
    showAllowlistConfirm.value = true;
    return;
  }
  finishSave({ allowLink: false });
};

defineExpose({
  goToNext,
  saveScenario,
  finishSave,
  currentStep,
  isPreviewStep,
  answers,
  previewData,
  showAllowlistConfirm,
});
</script>

<template>
  <div class="flex flex-col gap-5">
    <div v-if="!showAllowlistConfirm" class="flex flex-col gap-2">
      <span class="text-xs text-n-slate-11">
        {{
          t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.STEP_OF', {
            current: currentStep + 1,
            total: totalSteps,
          })
        }}
      </span>
      <div class="w-full h-1 rounded-full bg-n-alpha-2 overflow-hidden">
        <div
          class="h-full bg-n-brand rounded-full transition-all duration-300 motion-reduce:transition-none"
          :style="{ width: progressWidth }"
        />
      </div>
    </div>

    <div v-if="showAllowlistConfirm" class="flex flex-col gap-2">
      <h4 class="text-base font-medium text-n-slate-12 m-0">
        {{
          t(
            'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.ALLOWLIST_CONFIRM.TITLE',
            { host: bookingHost }
          )
        }}
      </h4>
      <p class="text-sm text-n-slate-11 m-0">
        {{
          t(
            'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.ALLOWLIST_CONFIRM.MESSAGE',
            { host: bookingHost }
          )
        }}
      </p>
    </div>

    <ScenarioForm
      v-else-if="isPreviewStep"
      ref="previewFormRef"
      v-model:title="previewData.title"
      v-model:description="previewData.description"
      v-model:instruction="previewData.instruction"
    />

    <div v-else class="flex flex-col gap-4 min-h-[12rem]">
      <div class="flex flex-col gap-1">
        <h4 class="text-base font-medium text-n-slate-12 m-0">
          {{ questionText('LABEL') }}
        </h4>
        <p v-if="questionText('HELP')" class="text-sm text-n-slate-11 m-0">
          {{ questionText('HELP') }}
        </p>
      </div>

      <Input
        v-if="['text', 'url', 'number'].includes(currentQuestion.type)"
        v-model="answers[currentQuestion.key]"
        :type="currentQuestion.type"
        :placeholder="questionText('PLACEHOLDER')"
        :message="questionError"
        :message-type="questionError ? 'error' : 'info'"
      />

      <div
        v-else-if="currentQuestion.type === 'select'"
        class="flex flex-col gap-3"
      >
        <div class="flex flex-wrap gap-2">
          <button
            v-for="option in currentQuestion.options"
            :key="option"
            type="button"
            class="inline-flex items-center gap-1 px-3 py-1.5 rounded-full text-sm border transition-colors motion-reduce:transition-none"
            :class="
              answers[currentQuestion.key] === option
                ? 'bg-n-brand/10 text-n-blue-11 border-n-brand'
                : 'text-n-slate-12 border-n-strong hover:bg-n-alpha-2'
            "
            :aria-pressed="answers[currentQuestion.key] === option"
            @click="answers[currentQuestion.key] = option"
          >
            <span
              v-if="answers[currentQuestion.key] === option"
              class="i-lucide-check size-3.5"
            />
            {{ optionLabel(option) }}
          </button>
        </div>
        <Input
          v-if="
            currentQuestion.otherKey && answers[currentQuestion.key] === 'other'
          "
          v-model="answers[currentQuestion.otherKey]"
          :placeholder="questionText('OTHER_PLACEHOLDER')"
        />
      </div>

      <div
        v-else-if="currentQuestion.type === 'chips'"
        class="flex flex-col gap-4"
      >
        <div
          v-for="group in currentQuestion.groups"
          :key="group.key"
          class="flex flex-col gap-1.5"
        >
          <span
            v-if="currentQuestion.groups.length > 1"
            class="text-xs text-n-slate-10"
          >
            {{ groupLabel(group.key) }}
          </span>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="option in group.options"
              :key="option"
              type="button"
              class="inline-flex items-center gap-1 px-3 py-1.5 rounded-full text-sm border transition-colors motion-reduce:transition-none"
              :class="
                isSelected(currentQuestion.key, option)
                  ? 'bg-n-brand/10 text-n-blue-11 border-n-brand'
                  : 'text-n-slate-12 border-n-strong hover:bg-n-alpha-2'
              "
              :aria-pressed="isSelected(currentQuestion.key, option)"
              :data-test="`chip-${option}`"
              @click="toggleOption(currentQuestion.key, option)"
            >
              <span
                v-if="isSelected(currentQuestion.key, option)"
                class="i-lucide-check size-3.5"
              />
              {{ fieldLabel(option) }}
            </button>
          </div>
        </div>

        <div v-if="currentQuestion.allowCustom" class="flex flex-col gap-1.5">
          <span class="text-xs text-n-slate-10">
            {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.GROUPS.CUSTOM') }}
          </span>
          <div
            v-if="customEntries(currentQuestion.key).length"
            class="flex flex-wrap gap-2"
          >
            <span
              v-for="entry in customEntries(currentQuestion.key)"
              :key="entry.label"
              class="inline-flex items-center gap-1 ps-3 pe-1.5 py-1.5 rounded-full text-sm border bg-n-brand/10 text-n-blue-11 border-n-brand"
              data-test="custom-entry"
            >
              <span class="i-lucide-check size-3.5" />
              {{ entry.label }}
              <button
                type="button"
                class="inline-flex items-center justify-center rounded-full p-0.5 hover:bg-n-alpha-2"
                :aria-label="
                  t(
                    'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.CUSTOM.REMOVE',
                    {
                      field: entry.label,
                    }
                  )
                "
                @click="removeCustomEntry(currentQuestion.key, entry)"
              >
                <span class="i-lucide-x size-3.5" />
              </button>
            </span>
          </div>
          <div
            v-if="
              customEntries(currentQuestion.key).length < MAX_CUSTOM_ENTRIES
            "
            class="flex items-start gap-2"
          >
            <div class="flex-1">
              <Input
                v-model="customEntry"
                :placeholder="
                  questionText('CUSTOM_PLACEHOLDER') ||
                  t(
                    'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.CUSTOM.PLACEHOLDER'
                  )
                "
                :message="customEntryError"
                :message-type="customEntryError ? 'error' : 'info'"
                data-test="custom-entry-input"
                @keydown.enter.prevent="addCustomEntry"
              />
            </div>
            <Button
              type="button"
              faded
              slate
              icon="i-lucide-plus"
              :disabled="!canAddCustom"
              :label="
                t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.CUSTOM.ADD')
              "
              data-test="custom-entry-add"
              @click="addCustomEntry"
            />
          </div>
        </div>
      </div>

      <div
        v-else-if="currentQuestion.type === 'label'"
        class="flex flex-col gap-3"
      >
        <Input
          v-model="answers.label"
          :placeholder="
            t(
              'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.LABEL_PLACEHOLDER'
            )
          "
          :message="
            questionError ||
            (answers.label &&
              (labelExists
                ? t(
                    'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.LABEL_EXISTS'
                  )
                : t(
                    'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.LABEL_NEW'
                  )))
          "
          :message-type="questionError ? 'error' : 'info'"
          data-test="label-input"
          @blur="normalizeLabel"
        />
        <div v-if="labelSuggestions.length" class="flex flex-wrap gap-2">
          <button
            v-for="label in labelSuggestions"
            :key="label.id"
            type="button"
            class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-sm border transition-colors motion-reduce:transition-none"
            :class="
              answers.label === label.title
                ? 'bg-n-brand/10 text-n-blue-11 border-n-brand'
                : 'text-n-slate-12 border-n-strong hover:bg-n-alpha-2'
            "
            @click="answers.label = label.title"
          >
            <span
              class="size-2 rounded-full"
              :style="{ backgroundColor: label.color }"
            />
            {{ label.title }}
          </button>
        </div>
      </div>
    </div>

    <div
      class="flex items-center justify-between w-full pt-4 border-t border-n-weak"
    >
      <Button
        type="button"
        faded
        slate
        :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.BACK')"
        @click="goToBack"
      />
      <div class="flex items-center gap-2">
        <template v-if="showAllowlistConfirm">
          <Button
            type="button"
            faded
            slate
            :disabled="isSaving"
            :label="
              t(
                'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.ALLOWLIST_CONFIRM.CANCEL'
              )
            "
            @click="finishSave({ allowLink: false })"
          />
          <Button
            type="button"
            :is-loading="isSaving"
            :label="
              t(
                'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.ALLOWLIST_CONFIRM.CONFIRM'
              )
            "
            @click="finishSave({ allowLink: true })"
          />
        </template>
        <Button
          v-else-if="isPreviewStep"
          type="button"
          :is-loading="isSaving"
          :label="
            t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.ADD_SCENARIO')
          "
          @click="saveScenario"
        />
        <template v-else>
          <Button
            v-if="
              !currentQuestion.required && currentQuestion.type !== 'select'
            "
            type="button"
            ghost
            slate
            :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.SKIP')"
            @click="goToNext"
          />
          <Button
            type="button"
            :disabled="!canProceed"
            :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.NEXT')"
            data-test="stepper-next"
            @click="goToNext"
          />
        </template>
      </div>
    </div>
  </div>
</template>

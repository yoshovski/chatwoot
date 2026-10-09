<script setup>
import { ref, reactive, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Editor from 'dashboard/components-next/Editor/Editor.vue';

const props = defineProps({
  template: {
    type: Object,
    default: null,
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

const emit = defineEmits(['add', 'updateAllowlist', 'close']);

const { t } = useI18n();
const dialogRef = ref(null);

const currentStep = ref(0);
const answers = reactive({});
const previewData = reactive({
  title: '',
  description: '',
  instruction: '',
});

// Confirmation state for allowlisting a domain
const showAllowlistConfirm = ref(false);
const pendingHost = ref('');

const questions = computed(() => props.template?.questions || []);
const totalSteps = computed(() => questions.value.length + 1); // questions + preview
const isPreviewStep = computed(
  () => currentStep.value === questions.value.length
);
const currentQuestion = computed(() => questions.value[currentStep.value]);

const initAnswers = () => {
  if (!props.template) return;
  questions.value.forEach(q => {
    answers[q.key] = Array.isArray(q.default)
      ? [...q.default]
      : (q.default ?? '');
  });
  currentStep.value = 0;
  showAllowlistConfirm.value = false;
  pendingHost.value = '';
};

watch(
  () => props.template,
  () => {
    initAnswers();
  },
  { immediate: true }
);

const progressPercentage = computed(() => {
  return Math.round(((currentStep.value + 1) / totalSteps.value) * 100);
});

const canProceed = computed(() => {
  if (isPreviewStep.value) {
    return Boolean(
      previewData.title?.trim() &&
        previewData.description?.trim() &&
        previewData.instruction?.trim()
    );
  }
  const q = currentQuestion.value;
  if (!q) return false;
  if (!q.required) return true;

  const val = answers[q.key];
  if (Array.isArray(val)) return val.length > 0;
  if (typeof val === 'number') return !Number.isNaN(val);
  return Boolean(val && String(val).trim());
});

const updatePreviewFromAnswers = () => {
  if (!props.template) return;
  const built = props.template.build(answers, props.tools);
  previewData.title = built.title;
  previewData.description = built.description;
  previewData.instruction = built.instruction;
};

const goToNext = () => {
  if (currentStep.value < questions.value.length - 1) {
    currentStep.value += 1;
  } else if (currentStep.value === questions.value.length - 1) {
    updatePreviewFromAnswers();
    currentStep.value += 1;
  }
};

const goToBack = () => {
  if (showAllowlistConfirm.value) {
    showAllowlistConfirm.value = false;
    return;
  }
  if (currentStep.value > 0) {
    currentStep.value -= 1;
  }
};

const skipCurrent = () => {
  goToNext();
};

const toggleChipOption = (key, val) => {
  const current = answers[key] || [];
  if (current.includes(val)) {
    answers[key] = current.filter(item => item !== val);
  } else {
    answers[key] = [...current, val];
  }
};

const extractHost = urlString => {
  try {
    const formatted = urlString.startsWith('http')
      ? urlString
      : `https://${urlString}`;
    return new URL(formatted).hostname;
  } catch {
    return '';
  }
};

const open = () => {
  initAnswers();
  dialogRef.value?.open();
};

const close = () => {
  dialogRef.value?.close();
  emit('close');
};

const saveScenario = async () => {
  // Check allowlist for booking url or links
  if (answers.booking_url) {
    const host = extractHost(answers.booking_url);
    const allowlist = props.assistant?.link_allowlist || [];
    if (host && !allowlist.includes(host) && !showAllowlistConfirm.value) {
      pendingHost.value = host;
      showAllowlistConfirm.value = true;
      return;
    }
  }

  emit('add', {
    title: previewData.title,
    description: previewData.description,
    instruction: previewData.instruction,
  });

  close();
};

const confirmAllowlistAndSave = () => {
  if (pendingHost.value) {
    emit('updateAllowlist', pendingHost.value);
  }
  showAllowlistConfirm.value = false;
  saveScenario();
};

const dismissAllowlistAndSave = () => {
  showAllowlistConfirm.value = false;
  saveScenario();
};

defineExpose({
  open,
  close,
  goToNext,
  saveScenario,
  currentStep,
  isPreviewStep,
  answers,
  previewData,
  showAllowlistConfirm,
  pendingHost,
});
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="2xl"
    :title="
      showAllowlistConfirm
        ? t(
            'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.ALLOWLIST_CONFIRM.TITLE',
            'Allow links in replies?'
          )
        : isPreviewStep
          ? t(
              'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.PREVIEW_TITLE',
              'Review scenario'
            )
          : template?.title || ''
    "
    :description="
      showAllowlistConfirm
        ? ''
        : isPreviewStep
          ? t(
              'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.PREVIEW_DESCRIPTION',
              'Review the generated title, routing trigger, and instructions. You can customize them before saving.'
            )
          : ''
    "
    :show-cancel-button="false"
    :show-confirm-button="false"
    overflow-y-auto
  >
    <!-- Stepper Progress Header -->
    <div v-if="!showAllowlistConfirm" class="flex flex-col gap-2 -mt-2 mb-2">
      <div class="flex items-center justify-between text-xs text-n-slate-11">
        <span>
          {{
            t(
              'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.STEP_OF',
              { current: currentStep + 1, total: totalSteps },
              `Step ${currentStep + 1} of ${totalSteps}`
            )
          }}
        </span>
        <span class="font-medium text-n-slate-12">
          {{
            isPreviewStep
              ? t(
                  'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.PREVIEW',
                  'Preview'
                )
              : currentQuestion?.label
          }}
        </span>
      </div>
      <div class="w-full h-1.5 rounded-full bg-n-alpha-2 overflow-hidden">
        <div
          class="h-full bg-n-brand transition-all duration-300 rounded-full"
          :style="{ width: `${progressPercentage}%` }"
        />
      </div>
    </div>

    <!-- Allowlist Confirmation View -->
    <div v-if="showAllowlistConfirm" class="flex flex-col gap-4 py-2">
      <p class="text-sm text-n-slate-12 leading-relaxed m-0">
        {{
          t(
            'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.ALLOWLIST_CONFIRM.MESSAGE',
            { host: pendingHost },
            `To share ${pendingHost} with customers, add it to your assistant's allowed link domains. Otherwise, links to ${pendingHost} will be stripped from messages.`
          )
        }}
      </p>

      <div
        class="flex items-center justify-end gap-3 pt-4 border-t border-n-weak"
      >
        <Button
          faded
          slate
          :label="
            t(
              'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.ALLOWLIST_CONFIRM.CANCEL',
              'Save without allowing'
            )
          "
          @click="dismissAllowlistAndSave"
        />
        <Button
          :label="
            t(
              'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.ALLOWLIST_CONFIRM.CONFIRM',
              'Allow and save'
            )
          "
          @click="confirmAllowlistAndSave"
        />
      </div>
    </div>

    <!-- Question View -->
    <div
      v-else-if="!isPreviewStep && currentQuestion"
      class="flex flex-col gap-4 py-2 min-h-[14rem]"
    >
      <div class="flex flex-col gap-1">
        <h4 class="text-base font-semibold text-n-slate-12 m-0">
          {{ currentQuestion.label }}
        </h4>
        <p
          v-if="currentQuestion.helperText"
          class="text-xs text-n-slate-11 m-0"
        >
          {{ currentQuestion.helperText }}
        </p>
      </div>

      <!-- Text Input -->
      <Input
        v-if="currentQuestion.type === 'text'"
        v-model="answers[currentQuestion.key]"
        :placeholder="currentQuestion.placeholder"
      />

      <!-- URL Input -->
      <Input
        v-else-if="currentQuestion.type === 'url'"
        v-model="answers[currentQuestion.key]"
        type="url"
        :placeholder="currentQuestion.placeholder"
      />

      <!-- Number Input -->
      <Input
        v-else-if="currentQuestion.type === 'number'"
        v-model.number="answers[currentQuestion.key]"
        type="number"
        :placeholder="currentQuestion.placeholder"
      />

      <!-- TextArea Input -->
      <TextArea
        v-else-if="currentQuestion.type === 'textarea'"
        v-model="answers[currentQuestion.key]"
        :placeholder="currentQuestion.placeholder"
      />

      <!-- Chips (Multi-Select) Input -->
      <div
        v-else-if="currentQuestion.type === 'chips'"
        class="flex flex-wrap gap-2 pt-1"
      >
        <button
          v-for="opt in currentQuestion.options"
          :key="opt.value"
          type="button"
          class="px-3 py-1.5 rounded-full text-xs font-medium border transition-colors select-none"
          :class="[
            (answers[currentQuestion.key] || []).includes(opt.value)
              ? 'bg-n-brand text-white border-n-brand'
              : 'bg-n-alpha-2 text-n-slate-12 border-n-weak hover:bg-n-alpha-3',
          ]"
          @click="toggleChipOption(currentQuestion.key, opt.value)"
        >
          {{ opt.label }}
        </button>
      </div>
    </div>

    <!-- Preview View -->
    <div v-else-if="isPreviewStep" class="flex flex-col gap-4 py-2">
      <Input
        v-model="previewData.title"
        :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.FORM.TITLE.LABEL')"
        :placeholder="
          t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.FORM.TITLE.PLACEHOLDER')
        "
      />

      <TextArea
        v-model="previewData.description"
        :max-length="500"
        :label="
          t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.FORM.DESCRIPTION.LABEL')
        "
        :placeholder="
          t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.FORM.DESCRIPTION.PLACEHOLDER')
        "
        show-character-count
      />

      <Editor
        v-model="previewData.instruction"
        :label="
          t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.FORM.INSTRUCTION.LABEL')
        "
        :placeholder="
          t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.FORM.INSTRUCTION.PLACEHOLDER')
        "
        :show-character-count="false"
        enable-captain-tools
      />
    </div>

    <!-- Footer Action Buttons -->
    <template #footer>
      <div
        v-if="!showAllowlistConfirm"
        class="flex items-center justify-between w-full pt-4 border-t border-n-weak"
      >
        <div>
          <Button
            v-if="currentStep > 0"
            faded
            slate
            :label="
              t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.BACK', 'Back')
            "
            type="button"
            @click="goToBack"
          />
        </div>

        <div class="flex items-center gap-2">
          <Button
            v-if="!isPreviewStep && !currentQuestion?.required"
            ghost
            slate
            :label="
              t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.SKIP', 'Skip')
            "
            type="button"
            @click="skipCurrent"
          />

          <Button
            v-if="!isPreviewStep"
            :disabled="!canProceed"
            :label="
              t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.NEXT', 'Next')
            "
            type="button"
            @click="goToNext"
          />

          <Button
            v-else
            :disabled="!canProceed"
            :label="
              t(
                'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.ADD_SCENARIO',
                'Add scenario'
              )
            "
            type="button"
            @click="saveScenario"
          />
        </div>
      </div>
    </template>
  </Dialog>
</template>

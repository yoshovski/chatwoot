<script setup>
import { ref, reactive, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import ScenarioForm from './ScenarioForm.vue';

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

const emit = defineEmits(['add', 'back', 'updateAllowlist']);

const { t } = useI18n();

const previewFormRef = ref(null);
const currentStep = ref(0);
const showAllowlistConfirm = ref(false);
const pendingHost = ref('');

const questions = computed(() => props.template.questions);

const answers = reactive(
  Object.fromEntries(
    props.template.questions.map(question => [
      question.key,
      Array.isArray(question.default)
        ? [...question.default]
        : (question.default ?? ''),
    ])
  )
);

const previewData = reactive({ title: '', description: '', instruction: '' });

const totalSteps = computed(() => questions.value.length + 1);
const isPreviewStep = computed(
  () => currentStep.value === questions.value.length
);
const currentQuestion = computed(() => questions.value[currentStep.value]);
const progressWidth = computed(
  () => `${((currentStep.value + 1) / totalSteps.value) * 100}%`
);

const canProceed = computed(() => {
  const question = currentQuestion.value;
  if (!question?.required) return true;
  const value = answers[question.key];
  if (Array.isArray(value)) return value.length > 0;
  return Boolean(String(value ?? '').trim());
});

const buildPreview = () => {
  Object.assign(previewData, props.template.build(answers, props.tools));
};

const goToNext = () => {
  if (currentStep.value === questions.value.length - 1) buildPreview();
  currentStep.value += 1;
};

const goToBack = () => {
  if (showAllowlistConfirm.value) {
    showAllowlistConfirm.value = false;
  } else if (currentStep.value === 0) {
    emit('back');
  } else {
    currentStep.value -= 1;
  }
};

const toggleChipOption = (key, value) => {
  const current = answers[key];
  answers[key] = current.includes(value)
    ? current.filter(item => item !== value)
    : [...current, value];
};

const extractHost = url => {
  try {
    return new URL(url.startsWith('http') ? url : `https://${url}`).hostname;
  } catch {
    return '';
  }
};

const emitAdd = () => {
  emit('add', { ...previewData });
};

const saveScenario = () => {
  if (!previewFormRef.value.validate()) return;

  if (answers.booking_url) {
    const host = extractHost(answers.booking_url);
    const allowlist = props.assistant?.link_allowlist || [];
    if (host && !allowlist.includes(host)) {
      pendingHost.value = host;
      showAllowlistConfirm.value = true;
      return;
    }
  }
  emitAdd();
};

const confirmAllowlistAndSave = () => {
  emit('updateAllowlist', pendingHost.value);
  emitAdd();
};

defineExpose({
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
  <div class="flex flex-col gap-5">
    <div v-if="!showAllowlistConfirm" class="flex flex-col gap-2">
      <div class="flex items-center justify-between text-xs text-n-slate-11">
        <span>
          {{
            t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.STEP_OF', {
              current: currentStep + 1,
              total: totalSteps,
            })
          }}
        </span>
      </div>
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
            'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.ALLOWLIST_CONFIRM.TITLE'
          )
        }}
      </h4>
      <p class="text-sm text-n-slate-11 m-0">
        {{
          t(
            'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.ALLOWLIST_CONFIRM.MESSAGE',
            { host: pendingHost }
          )
        }}
      </p>
    </div>

    <div
      v-else-if="!isPreviewStep"
      class="flex flex-col gap-4 min-h-[12rem]"
    >
      <div class="flex flex-col gap-1">
        <h4 class="text-base font-medium text-n-slate-12 m-0">
          {{ currentQuestion.label }}
        </h4>
        <p
          v-if="currentQuestion.helperText"
          class="text-sm text-n-slate-11 m-0"
        >
          {{ currentQuestion.helperText }}
        </p>
      </div>

      <Input
        v-if="['text', 'url'].includes(currentQuestion.type)"
        v-model="answers[currentQuestion.key]"
        :type="currentQuestion.type"
        :placeholder="currentQuestion.placeholder"
      />
      <Input
        v-else-if="currentQuestion.type === 'number'"
        v-model.number="answers[currentQuestion.key]"
        type="number"
        :placeholder="currentQuestion.placeholder"
      />
      <TextArea
        v-else-if="currentQuestion.type === 'textarea'"
        v-model="answers[currentQuestion.key]"
        :placeholder="currentQuestion.placeholder"
      />
      <div
        v-else-if="currentQuestion.type === 'chips'"
        class="flex flex-wrap gap-2"
      >
        <button
          v-for="option in currentQuestion.options"
          :key="option.value"
          type="button"
          class="inline-flex items-center gap-1 px-3 py-1.5 rounded-full text-sm border transition-colors motion-reduce:transition-none"
          :class="
            answers[currentQuestion.key].includes(option.value)
              ? 'bg-n-brand/10 text-n-blue-11 border-n-brand'
              : 'text-n-slate-12 border-n-weak hover:bg-n-alpha-2'
          "
          @click="toggleChipOption(currentQuestion.key, option.value)"
        >
          <span
            v-if="answers[currentQuestion.key].includes(option.value)"
            class="i-lucide-check size-3.5"
          />
          {{ option.label }}
        </button>
      </div>
    </div>

    <ScenarioForm
      v-else
      ref="previewFormRef"
      v-model:title="previewData.title"
      v-model:description="previewData.description"
      v-model:instruction="previewData.instruction"
    />

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
            :label="
              t(
                'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.ALLOWLIST_CONFIRM.CANCEL'
              )
            "
            @click="emitAdd"
          />
          <Button
            type="button"
            :label="
              t(
                'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.ALLOWLIST_CONFIRM.CONFIRM'
              )
            "
            @click="confirmAllowlistAndSave"
          />
        </template>
        <Button
          type="button"
          v-else-if="isPreviewStep"
          :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.ADD_SCENARIO')"
          @click="saveScenario"
        />
        <template v-else>
          <Button
            type="button"
            v-if="!currentQuestion.required"
            ghost
            slate
            :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.SKIP')"
            @click="goToNext"
          />
          <Button
            type="button"
            :disabled="!canProceed"
            :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPPER.NEXT')"
            @click="goToNext"
          />
        </template>
      </div>
    </div>
  </div>
</template>

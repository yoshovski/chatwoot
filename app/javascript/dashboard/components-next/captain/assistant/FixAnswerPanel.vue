<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import SidePanel from 'dashboard/components-next/side-panel/SidePanel.vue';

// Fix a test reply: save the right answer as an FAQ, or add a rule the AI agent follows from now on.
const props = defineProps({
  assistantId: { type: Number, required: true },
});

const emit = defineEmits(['saved']);

const MODES = { FAQ: 'faq', RULE: 'rule' };
const ANSWER_MAX_LENGTH = 4000;
const RULE_MAX_LENGTH = 500;

const { t } = useI18n();
const store = useStore();

const panel = ref(null);
const mode = ref(MODES.FAQ);
const question = ref('');
const answer = ref('');
const rule = ref('');
const isSaving = ref(false);
let reply = null;

const modes = computed(() => [
  { value: MODES.FAQ, label: t('CAPTAIN.PLAYGROUND.WIDGET_TEST.FIX.AS_FAQ') },
  { value: MODES.RULE, label: t('CAPTAIN.PLAYGROUND.WIDGET_TEST.FIX.AS_RULE') },
]);
const canSave = computed(() =>
  mode.value === MODES.FAQ
    ? Boolean(question.value.trim() && answer.value.trim())
    : Boolean(rule.value.trim())
);

const open = selectedReply => {
  reply = selectedReply;
  mode.value = MODES.FAQ;
  question.value = selectedReply.question;
  answer.value = selectedReply.answer || '';
  rule.value = '';
  panel.value.open();
};
defineExpose({ open });

const saveFaq = () =>
  store.dispatch('captainResponses/create', {
    question: question.value.trim(),
    answer: answer.value.trim(),
    assistant_id: props.assistantId,
  });

// Read the saved rules first, so a rule added in another tab is kept.
const saveRule = async () => {
  const assistant = await store.dispatch(
    'captainAssistants/show',
    props.assistantId
  );
  const rules = assistant?.response_guidelines || [];
  await store.dispatch('captainAssistants/update', {
    id: props.assistantId,
    assistant: { response_guidelines: [...rules, rule.value.trim()] },
  });
};

const save = async () => {
  if (!canSave.value || isSaving.value) return;
  isSaving.value = true;
  try {
    await (mode.value === MODES.FAQ ? saveFaq() : saveRule());
    useAlert(t('CAPTAIN.PLAYGROUND.WIDGET_TEST.FIX.SAVED'));
    emit('saved', reply);
    panel.value.close();
  } catch (error) {
    useAlert(
      error?.response?.data?.message ||
        error?.message ||
        t('CAPTAIN.PLAYGROUND.WIDGET_TEST.FIX.ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <SidePanel
    ref="panel"
    width="lg"
    :title="t('CAPTAIN.PLAYGROUND.WIDGET_TEST.FIX.TITLE')"
    :description="t('CAPTAIN.PLAYGROUND.WIDGET_TEST.FIX.DESCRIPTION')"
  >
    <div class="flex flex-col gap-5">
      <div
        class="flex gap-0.5 rounded-lg bg-n-alpha-1 p-0.5"
        role="group"
        :aria-label="t('CAPTAIN.PLAYGROUND.WIDGET_TEST.FIX.TITLE')"
      >
        <button
          v-for="option in modes"
          :key="option.value"
          type="button"
          class="flex-1 rounded-md px-3 py-1.5 text-sm font-medium transition-colors"
          :class="
            mode === option.value
              ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          :aria-pressed="mode === option.value"
          @click="mode = option.value"
        >
          {{ option.label }}
        </button>
      </div>

      <template v-if="mode === MODES.FAQ">
        <p class="mb-0 text-sm text-n-slate-11">
          {{ t('CAPTAIN.PLAYGROUND.WIDGET_TEST.FIX.FAQ_HINT') }}
        </p>
        <Input
          v-model="question"
          :label="t('CAPTAIN.PLAYGROUND.WIDGET_TEST.FIX.QUESTION')"
        />
        <TextArea
          v-model="answer"
          :label="t('CAPTAIN.PLAYGROUND.WIDGET_TEST.FIX.ANSWER')"
          :max-length="ANSWER_MAX_LENGTH"
          auto-height
          min-height="8rem"
          max-height="20rem"
        />
      </template>
      <template v-else>
        <p class="mb-0 text-sm text-n-slate-11">
          {{ t('CAPTAIN.PLAYGROUND.WIDGET_TEST.FIX.RULE_HINT') }}
        </p>
        <TextArea
          v-model="rule"
          :label="t('CAPTAIN.PLAYGROUND.WIDGET_TEST.FIX.RULE')"
          :placeholder="
            t('CAPTAIN.PLAYGROUND.WIDGET_TEST.FIX.RULE_PLACEHOLDER')
          "
          :max-length="RULE_MAX_LENGTH"
          auto-height
          min-height="6rem"
        />
      </template>
    </div>
    <template #footer>
      <div class="flex w-full justify-end">
        <NextButton
          sm
          :label="t('CAPTAIN.PLAYGROUND.WIDGET_TEST.FIX.SAVE')"
          :disabled="!canSave"
          :is-loading="isSaving"
          @click="save"
        />
      </div>
    </template>
  </SidePanel>
</template>

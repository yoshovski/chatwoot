import { computed, ref, unref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import api from 'dashboard/api/captain/knowledgeSources';

const TONES = ['friendly', 'professional', 'short'];
const EXAMPLE_KEYS = ['EXAMPLE_1', 'EXAMPLE_2', 'EXAMPLE_3'];
const QUICK_REPLY_KEYS = [
  'BUTTON_1',
  'BUTTON_2',
  'BUTTON_3',
  'BUTTON_4',
  'BUTTON_5',
];

// One request per agent and page load; the server decides when examples are regenerated.
const requests = new Map();
const fetchExamples = assistantId => {
  if (!requests.has(assistantId)) {
    requests.set(
      assistantId,
      api
        .examples(assistantId)
        .then(({ data }) => data.examples)
        .catch(() => null)
        .then(examples => {
          // Generation runs in the background, so try again on the next visit.
          if (!examples) requests.delete(assistantId);
          return examples;
        })
    );
  }
  return requests.get(assistantId);
};

// Examples written for this business, with generic copy until they are ready.
export function useBusinessExamples(assistantId) {
  const { t } = useI18n();
  const examples = ref(null);

  watch(
    () => unref(assistantId),
    async id => {
      examples.value = null;
      if (!id) return;
      const data = await fetchExamples(id);
      if (unref(assistantId) === id) examples.value = data;
    },
    { immediate: true }
  );

  const question = computed(
    () =>
      examples.value?.question ||
      t('CAPTAIN.ASSISTANTS.SETTINGS.PREVIEW.QUESTION')
  );
  const reply = tone => {
    const key = TONES.includes(tone) ? tone : 'friendly';
    return (
      examples.value?.replies?.[key] ||
      t(`CAPTAIN.ASSISTANTS.SETTINGS.PREVIEW.REPLY.${key.toUpperCase()}`)
    );
  };
  const quickReplies = computed(
    () =>
      examples.value?.quick_replies ||
      QUICK_REPLY_KEYS.map(key =>
        t(`CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.QUICK_REPLIES.${key}`)
      )
  );
  const offLimitsQuestion = computed(
    () =>
      examples.value?.off_limits_question ||
      t('CAPTAIN.ASSISTANTS.SETTINGS.PREVIEW.OFF_TOPIC_QUESTION')
  );
  const guardrails = computed(
    () =>
      examples.value?.guardrails ||
      EXAMPLE_KEYS.map(key =>
        t(`CAPTAIN.ASSISTANTS.GUARDRAILS.ADD.SUGGESTED.EXAMPLES.${key}`)
      )
  );
  const guidelines = computed(
    () =>
      examples.value?.guidelines ||
      EXAMPLE_KEYS.map(key =>
        t(
          `CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.ADD.SUGGESTED.EXAMPLES.${key}`
        )
      )
  );
  const starterQuestions = computed(() => {
    const questions =
      examples.value?.starter_questions ||
      EXAMPLE_KEYS.map(key => t(`CAPTAIN.PLAYGROUND.STARTER_QUESTIONS.${key}`));
    const handoff =
      examples.value?.handoff_question ||
      t('CAPTAIN.ASSISTANTS.SETTINGS.PREVIEW.HANDOFF_QUESTION');
    return [...questions, handoff];
  });

  return {
    question,
    reply,
    quickReplies,
    offLimitsQuestion,
    guardrails,
    guidelines,
    starterQuestions,
  };
}

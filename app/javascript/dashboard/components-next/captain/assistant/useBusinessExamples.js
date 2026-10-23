import { computed, reactive, unref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import api from 'dashboard/api/captain/knowledgeSources';

const TONES = ['friendly', 'professional', 'short'];
const ANSWER_LENGTHS = ['short', 'balanced', 'detailed'];
const EXAMPLE_KEYS = ['EXAMPLE_1', 'EXAMPLE_2', 'EXAMPLE_3'];
const QUICK_REPLY_KEYS = [
  'BUTTON_1',
  'BUTTON_2',
  'BUTTON_3',
  'BUTTON_4',
  'BUTTON_5',
];

const REFRESH_POLL_MS = 3000;
const REFRESH_POLL_ATTEMPTS = 20;

// One request per agent and page load; the server decides when examples are regenerated.
const requests = new Map();
// Examples per agent, shared by every preview on the page so a refresh updates all of them.
const store = reactive({});

const fetchExamples = assistantId => {
  if (!requests.has(assistantId)) {
    requests.set(
      assistantId,
      api
        .examples(assistantId)
        .then(({ data }) => data)
        .catch(() => null)
        .then(data => {
          // Generation runs in the background, so try again on the next visit.
          if (!data?.examples) requests.delete(assistantId);
          return data;
        })
    );
  }
  return requests.get(assistantId);
};

const wait = ms =>
  new Promise(resolve => {
    setTimeout(resolve, ms);
  });

// After the owner saves business details: ask for new examples now and poll until they arrive.
export async function refreshBusinessExamples(assistantId) {
  requests.delete(assistantId);
  try {
    const { data } = await api.examples(assistantId, { refresh: true });
    const previous = data.generated_at;
    for (let attempt = 0; attempt < REFRESH_POLL_ATTEMPTS; attempt += 1) {
      // eslint-disable-next-line no-await-in-loop
      await wait(REFRESH_POLL_MS);
      // eslint-disable-next-line no-await-in-loop
      const { data: next } = await api.examples(assistantId);
      if (next.generated_at && next.generated_at !== previous) {
        store[assistantId] = next.examples;
        return;
      }
    }
  } catch {
    // The next page visit picks the new examples up.
  }
}

// Examples written for this business, with generic copy until they are ready.
export function useBusinessExamples(assistantId) {
  const { t } = useI18n();
  const examples = computed(() => store[unref(assistantId)] || null);

  watch(
    () => unref(assistantId),
    async id => {
      if (!id || store[id]) return;
      const data = await fetchExamples(id);
      if (data?.examples) store[id] = data.examples;
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
  // A custom length previews as balanced; the exact wording is for the Playground.
  const howToQuestion = computed(
    () =>
      examples.value?.how_to?.question ||
      t('CAPTAIN.ASSISTANTS.SETTINGS.PREVIEW.HOW_TO.QUESTION')
  );
  const howToReply = length => {
    const key = ANSWER_LENGTHS.includes(length) ? length : 'balanced';
    return (
      examples.value?.how_to?.[key] ||
      t(`CAPTAIN.ASSISTANTS.SETTINGS.PREVIEW.HOW_TO.${key.toUpperCase()}`)
    );
  };
  // The page each example question comes from; empty until examples are ready or when no page matches.
  const sources = computed(() => examples.value?.sources || {});
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
    howToQuestion,
    howToReply,
    sources,
    quickReplies,
    offLimitsQuestion,
    guardrails,
    guidelines,
    starterQuestions,
  };
}

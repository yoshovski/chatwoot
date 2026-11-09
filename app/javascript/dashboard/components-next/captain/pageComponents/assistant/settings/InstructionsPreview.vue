<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useBusinessExamples } from 'dashboard/components-next/captain/assistant/useBusinessExamples';
import AssistantChatPreview from './AssistantChatPreview.vue';

const props = defineProps({
  assistant: {
    type: Object,
    default: () => ({}),
  },
  showProductCards: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
const examples = useBusinessExamples(computed(() => props.assistant.id));

const config = computed(() => props.assistant.config || {});
// One question and one answer. The opening words follow the tone, the body follows
// the answer length, and the extras appear around it.
const TONE_OPENERS = ['friendly', 'professional'];
const answer = computed(() => {
  const body = examples.howToReply(config.value.answer_length || 'balanced');
  const tone = config.value.tone || 'friendly';
  return TONE_OPENERS.includes(tone)
    ? `${t(`CAPTAIN.AGENT_UX.STYLE.OPENER.${tone.toUpperCase()}`)} ${body}`
    : body;
});
const showFollowUp = computed(
  () =>
    config.value.follow_up_questions !== false &&
    (config.value.business_type || props.assistant.detected_business_type) !==
      'commerce'
);
const quickReplies = computed(() =>
  config.value.suggested_replies
    ? examples.quickReplies.value.slice(
        0,
        config.value.max_suggested_replies ?? 3
      )
    : []
);
const previewSources = computed(() => {
  const source =
    examples.sources.value.how_to || examples.sources.value.question;
  return source ? [source] : [];
});
const helpfulLink = computed(() =>
  config.value.helpful_links_mode === 'on_request'
    ? null
    : previewSources.value[0]
);
const showProductCard = computed(
  () => props.showProductCards && config.value.product_cards
);
</script>

<template>
  <AssistantChatPreview
    :name="assistant.name"
    :avatar-url="assistant.avatar_url"
  >
    <p class="preview-bubble preview-bubble--customer">
      {{ examples.howToQuestion.value }}
    </p>
    <div class="flex flex-col self-start gap-2 max-w-[88%]">
      <p class="preview-bubble preview-bubble--agent !max-w-full">
        {{ answer }}
        <a
          v-if="helpfulLink"
          :href="helpfulLink.url"
          target="_blank"
          rel="noopener noreferrer"
          class="block mt-2 underline text-n-blue-11 underline-offset-2"
        >
          {{
            t('CAPTAIN.ASSISTANTS.SETTINGS.PREVIEW.READ_MORE', {
              title: helpfulLink.title,
            })
          }}
        </a>
      </p>
      <p
        v-if="showFollowUp"
        class="preview-bubble preview-bubble--agent !max-w-full"
      >
        {{ t('CAPTAIN.AGENT_UX.STYLE.FOLLOW_UP_EXAMPLE') }}
      </p>
      <div
        v-if="showProductCard"
        class="flex items-center gap-2.5 p-2 rounded-xl bg-n-solid-1 outline outline-1 outline-n-weak"
      >
        <span
          class="flex items-center justify-center rounded-lg size-10 bg-n-slate-3 text-n-slate-10 shrink-0"
        >
          <span class="i-lucide-package size-4" />
        </span>
        <span class="flex flex-col text-xs">
          <span class="font-medium text-n-slate-12">
            {{
              t(
                'CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.PRODUCT_CARDS.PREVIEW_NAME'
              )
            }}
          </span>
          <span class="text-n-slate-11">
            {{
              t(
                'CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.PRODUCT_CARDS.PREVIEW_PRICE'
              )
            }}
          </span>
        </span>
      </div>
      <div v-if="quickReplies.length" class="flex flex-wrap gap-1.5">
        <span
          v-for="label in quickReplies"
          :key="label"
          class="px-2.5 py-1 text-xs rounded-full bg-n-solid-1 outline outline-1 outline-n-blue-7 text-n-blue-11"
        >
          {{ label }}
        </span>
      </div>
    </div>
  </AssistantChatPreview>
</template>

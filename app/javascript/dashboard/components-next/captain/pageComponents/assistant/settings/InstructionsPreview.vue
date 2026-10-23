<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useBusinessExamples } from 'dashboard/components-next/captain/assistant/useBusinessExamples';
import MessageSources from 'shared/components/MessageSources.vue';
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
const previewType = ref('howTo');
const previewTypes = ['simple', 'howTo'];
const question = computed(() =>
  previewType.value === 'simple'
    ? examples.question.value
    : examples.howToQuestion.value
);
const reply = computed(() =>
  previewType.value === 'simple'
    ? examples.reply(config.value.tone)
    : examples.howToReply(config.value.answer_length || 'balanced')
);
watch(
  () => config.value.tone,
  () => {
    previewType.value = 'simple';
  }
);
watch(
  () => config.value.answer_length,
  () => {
    previewType.value = 'howTo';
  }
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
    examples.sources.value[
      previewType.value === 'simple' ? 'question' : 'how_to'
    ];
  return source ? [source] : [];
});
const showProductCard = computed(
  () => props.showProductCards && config.value.product_cards
);
</script>

<template>
  <div
    class="flex gap-1 p-1 rounded-lg bg-n-alpha-1"
    role="group"
    :aria-label="t('CAPTAIN.ASSISTANTS.SETTINGS.PREVIEW.EXAMPLE_TYPE')"
  >
    <button
      v-for="type in previewTypes"
      :key="type"
      type="button"
      :aria-pressed="previewType === type"
      class="flex-1 rounded-md px-3 py-1.5 text-xs font-medium transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
      :class="
        previewType === type
          ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
          : 'text-n-slate-11 hover:text-n-slate-12'
      "
      @click="previewType = type"
    >
      {{ t(`CAPTAIN.ASSISTANTS.SETTINGS.PREVIEW.EXAMPLE_TYPES.${type}`) }}
    </button>
  </div>
  <AssistantChatPreview
    :name="assistant.name"
    :avatar-url="assistant.avatar_url"
  >
    <p class="preview-bubble preview-bubble--customer">
      {{ question }}
    </p>
    <div class="flex flex-col self-start gap-2 max-w-[88%]">
      <p class="preview-bubble preview-bubble--agent !max-w-full">
        {{ reply }}
        <MessageSources
          v-if="config.feature_citation && previewSources.length"
          :sources="previewSources"
          :label="t('CONVERSATION.CAPTAIN_SOURCES')"
        />
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

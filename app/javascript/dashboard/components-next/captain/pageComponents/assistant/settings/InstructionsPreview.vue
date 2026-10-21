<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
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

const BUTTON_KEYS = [
  'BUTTON_1',
  'BUTTON_2',
  'BUTTON_3',
  'BUTTON_4',
  'BUTTON_5',
];

const config = computed(() => props.assistant.config || {});
const tone = computed(() =>
  ['friendly', 'professional', 'short'].includes(config.value.tone)
    ? config.value.tone
    : 'friendly'
);
const reply = computed(() =>
  t(`CAPTAIN.ASSISTANTS.SETTINGS.PREVIEW.REPLY.${tone.value.toUpperCase()}`)
);
const quickReplies = computed(() =>
  config.value.suggested_replies
    ? BUTTON_KEYS.slice(0, config.value.max_suggested_replies ?? 3).map(key =>
        t(`CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.QUICK_REPLIES.${key}`)
      )
    : []
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
      {{ t('CAPTAIN.ASSISTANTS.SETTINGS.PREVIEW.QUESTION') }}
    </p>
    <div class="flex flex-col self-start gap-2 max-w-[88%]">
      <p class="preview-bubble preview-bubble--agent !max-w-full">
        {{ reply }}
        <span
          v-if="config.feature_citation"
          class="block mt-1.5 text-xs text-n-blue-11"
        >
          {{
            t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.SOURCES.PREVIEW_LINK')
          }}
        </span>
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

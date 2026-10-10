<script setup>
import { computed } from 'vue';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import PlaygroundCards from './PlaygroundCards.vue';
import PlaygroundForm from './PlaygroundForm.vue';
import PlaygroundRunDetails from './PlaygroundRunDetails.vue';
import { accentAttrs } from './playgroundAccent';

const props = defineProps({
  message: { type: Object, required: true },
  widgetColor: { type: String, default: '' },
  widgetTextColor: { type: String, default: '' },
  // Only the newest reply can still be answered by clicking a suggestion, like in the widget.
  isLatest: { type: Boolean, default: false },
});

const emit = defineEmits(['selectOption']);

const { formatMessage } = useMessageFormatter();

const BUBBLE = 'rounded-2xl bg-n-slate-3 px-4 py-3 text-sm text-n-slate-12';

// Results from before the customer view existed only carry the answer text.
const parts = computed(() =>
  props.message.messages?.length
    ? props.message.messages
    : [{ content: props.message.content, content_type: 'text' }]
);

const options = part => part.content_attributes?.items ?? [];

const isOptionDisabled = () =>
  !props.isLatest || Boolean(props.message.selectedOption);

const isSelected = option => props.message.selectedOption === option.title;
</script>

<template>
  <div class="flex min-w-0 flex-col gap-1.5">
    <template v-for="(part, index) in parts" :key="index">
      <PlaygroundCards
        v-if="['cards', 'article'].includes(part.content_type)"
        :items="part.content_attributes?.items"
        :widget-color="widgetColor"
        :widget-text-color="widgetTextColor"
      />
      <PlaygroundForm
        v-else-if="part.content_type === 'form'"
        :content="part.content"
        :items="part.content_attributes?.items"
        :button-label="part.content_attributes?.button_label"
        :widget-color="widgetColor"
        :widget-text-color="widgetTextColor"
      />
      <template v-else>
        <div
          class="[overflow-wrap:break-word]"
          :class="[BUBBLE]"
          :data-test="`playground-${part.content_type}`"
        >
          <div v-dompurify-html="formatMessage(part.content)" />
        </div>
        <ul
          v-if="part.content_type === 'input_select'"
          class="m-0 flex list-none flex-wrap gap-1.5 p-0"
        >
          <li v-for="option in options(part)" :key="option.value">
            <button
              type="button"
              class="rounded-full border border-solid border-n-strong px-3.5 py-1.5 text-start text-sm disabled:cursor-not-allowed"
              :class="
                isSelected(option)
                  ? ''
                  : 'bg-n-background text-n-slate-12 disabled:opacity-50'
              "
              v-bind="
                isSelected(option)
                  ? accentAttrs(widgetColor, widgetTextColor)
                  : {}
              "
              :disabled="isOptionDisabled()"
              @click="emit('selectOption', option)"
            >
              {{ option.title }}
            </button>
          </li>
        </ul>
      </template>
    </template>
    <PlaygroundRunDetails
      v-if="message.runDetails && message.setupSummary"
      :run-details="message.runDetails"
      :setup-summary="message.setupSummary"
    />
  </div>
</template>

<script setup>
import { computed } from 'vue';
import BaseBubble from './Base.vue';
import FormattedContent from './Text/FormattedContent.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useI18n } from 'vue-i18n';
import { CONTENT_TYPES } from '../constants.js';
import { useMessageContext } from '../provider.js';

const { content, contentAttributes, contentType } = useMessageContext();
const { t } = useI18n();

const formValues = computed(() => {
  if (contentType.value === CONTENT_TYPES.FORM) {
    const { items, submittedValues = [] } = contentAttributes.value;

    if (submittedValues.length) {
      return submittedValues.map(submittedValue => {
        const item = items.find(
          formItem => formItem.name === submittedValue.name
        );
        return {
          title: submittedValue.value,
          value: submittedValue.value,
          label: item?.label,
        };
      });
    }

    return [];
  }

  return [];
});

// Reply buttons show what was offered, with the customer's pick highlighted,
// instead of a "No response" line under every bot reply.
const offeredOptions = computed(() => {
  if (contentType.value !== CONTENT_TYPES.INPUT_SELECT) return [];

  const [picked] = contentAttributes.value?.submittedValues ?? [];
  return (contentAttributes.value?.items ?? []).map(item => ({
    title: item.title,
    picked: !!picked && picked.value === item.value,
  }));
});
</script>

<template>
  <BaseBubble class="px-4 py-3" data-bubble-name="csat">
    <FormattedContent :content="content" />
    <div v-if="offeredOptions.length" class="flex flex-wrap gap-1.5 mt-3">
      <span
        v-for="option in offeredOptions"
        :key="option.title"
        class="inline-flex items-center gap-1 px-2 py-0.5 text-xs border rounded-full"
        :class="
          option.picked
            ? 'border-n-strong text-n-slate-12 font-medium'
            : 'border-n-weak text-n-slate-11'
        "
      >
        <Icon v-if="option.picked" icon="i-ph-check" class="size-3" />
        {{ option.title }}
      </span>
    </div>
    <dl v-else-if="formValues.length" class="mt-4">
      <template v-for="item in formValues" :key="item.title">
        <dt class="text-n-slate-11 italic mt-2">
          {{ item.label || t('CONVERSATION.RESPONSE') }}
        </dt>
        <dd>{{ item.title }}</dd>
      </template>
    </dl>
  </BaseBubble>
</template>

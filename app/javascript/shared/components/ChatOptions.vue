<script>
import ChatOption from 'shared/components/ChatOption.vue';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';

export default {
  components: {
    ChatOption,
  },
  props: {
    title: {
      type: String,
      default: '',
    },
    options: {
      type: Array,
      default: () => [],
    },
    selected: {
      type: String,
      default: '',
    },
    hideFields: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['optionSelect'],
  setup() {
    const { formatMessage } = useMessageFormatter();
    return {
      formatMessage,
    };
  },
  methods: {
    isSelected(option) {
      return this.selected === option.id;
    },
    onClick(selectedOption) {
      this.$emit('optionSelect', selectedOption);
    },
  },
};
</script>

<template>
  <div class="flex max-w-[90%] flex-col gap-3 mt-1">
    <h4
      class="chat-bubble agent !py-3 !px-4 rounded-2xl bg-n-alpha-2 dark:bg-n-solid-3 text-n-slate-12 text-sm font-normal leading-[1.5]"
    >
      <div
        v-dompurify-html="formatMessage(title, false)"
        class="text-n-slate-12"
      />
    </h4>
    <ul v-if="!hideFields" class="flex w-full flex-col items-end gap-2 px-1">
      <ChatOption
        v-for="option in options"
        :key="option.id"
        :action="option"
        :is-selected="isSelected(option)"
        class="list-none p-0"
        @option-select="onClick"
      />
    </ul>
  </div>
</template>

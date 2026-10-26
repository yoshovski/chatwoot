<script>
import { defineAsyncComponent } from 'vue';
import { mapGetters } from 'vuex';

import ChatAttachmentButton from 'widget/components/ChatAttachment.vue';
import ChatSendButton from 'widget/components/ChatSendButton.vue';
import { useAttachments } from '../composables/useAttachments';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import ResizableTextArea from 'shared/components/ResizableTextArea.vue';

const EmojiPicker = defineAsyncComponent(
  () => import('shared/components/emoji/EmojiPicker.vue')
);

export default {
  name: 'ChatInputWrap',
  components: {
    ChatAttachmentButton,
    ChatSendButton,
    EmojiPicker,
    FluentIcon,
    ResizableTextArea,
  },
  props: {
    onSendMessage: {
      type: Function,
      default: () => {},
    },
    onSendAttachment: {
      type: Function,
      default: () => {},
    },
  },
  setup() {
    const {
      canHandleAttachments,
      shouldShowEmojiPicker,
      hasEmojiPickerEnabled,
    } = useAttachments();
    return {
      canHandleAttachments,
      shouldShowEmojiPicker,
      hasEmojiPickerEnabled,
    };
  },
  data() {
    return {
      userInput: '',
      showEmojiPicker: false,
      attachedFile: null,
    };
  },

  computed: {
    ...mapGetters({
      isWidgetOpen: 'appConfig/getIsWidgetOpen',
      shouldShowEmojiPicker: 'appConfig/getShouldShowEmojiPicker',
    }),
    hasInput() {
      return this.userInput.trim().length > 0 || Boolean(this.attachedFile);
    },
    attachedFileName() {
      return (
        this.attachedFile?.fileName ||
        this.attachedFile?.file?.name ||
        this.$t('ATTACHMENTS.file.CONTENT')
      );
    },
  },
  watch: {
    isWidgetOpen(isWidgetOpen) {
      if (isWidgetOpen) {
        this.focusInput();
      }
    },
  },
  unmounted() {
    document.removeEventListener('keypress', this.handleEnterKeyPress);
  },
  mounted() {
    document.addEventListener('keypress', this.handleEnterKeyPress);
    if (this.isWidgetOpen) {
      this.focusInput();
    }
  },

  methods: {
    onAttachFile(attachment) {
      this.attachedFile = attachment;
      this.focusInput();
    },
    removeAttachedFile() {
      this.attachedFile = null;
      this.focusInput();
    },
    handleButtonClick() {
      if (this.attachedFile) {
        this.onSendAttachment({
          attachment: this.attachedFile,
          content: this.userInput.trim() || undefined,
        });
        this.attachedFile = null;
      } else if (this.userInput && this.userInput.trim()) {
        this.onSendMessage(this.userInput);
      }
      this.userInput = '';
      this.focusInput();
    },
    handleEnterKeyPress(e) {
      if (e.keyCode === 13 && !e.shiftKey) {
        e.preventDefault();
        this.handleButtonClick();
      }
    },
    toggleEmojiPicker() {
      this.showEmojiPicker = !this.showEmojiPicker;
    },
    hideEmojiPicker(e) {
      if (this.showEmojiPicker) {
        e.stopPropagation();
        this.toggleEmojiPicker();
      }
    },
    emojiOnClick(emoji) {
      this.userInput = `${this.userInput}${emoji} `;
    },
    onSelectEmoji({ value }) {
      this.emojiOnClick(value);
    },
    onTypingOff() {
      this.toggleTyping('off');
    },
    onTypingOn() {
      this.toggleTyping('on');
    },
    toggleTyping(typingStatus) {
      this.$store.dispatch('conversation/toggleUserTyping', { typingStatus });
    },
    focusInput() {
      this.$refs.chatInput.focus();
    },
  },
};
</script>

<template>
  <div class="flex flex-col pt-3" @keydown.esc="hideEmojiPicker">
    <div
      v-if="attachedFile"
      class="mb-2 rounded-[7px] bg-n-slate-3 px-2 py-1.5 text-sm text-n-slate-11 flex items-center gap-2"
    >
      <img
        v-if="attachedFile.fileType === 'image'"
        :src="attachedFile.thumbUrl"
        class="h-6 w-6 rounded object-cover"
        alt="Attachment preview"
      />
      <FluentIcon v-else icon="document" size="16" class="flex-shrink-0" />
      <div class="items-center flex-grow truncate text-xs">
        {{ attachedFileName }}
      </div>
      <button
        type="button"
        class="items-end flex-shrink-0 p-1 rounded-md hover:bg-n-slate-5 text-n-slate-11"
        :aria-label="$t('ATTACHMENTS.REMOVE')"
        @click="removeAttachedFile"
      >
        <FluentIcon icon="dismiss" size="12" />
      </button>
    </div>
    <ResizableTextArea
      id="chat-input"
      ref="chatInput"
      v-model="userInput"
      :rows="1"
      :aria-label="$t('CHAT_PLACEHOLDER')"
      :placeholder="$t('CHAT_PLACEHOLDER')"
      class="reset-base h-8 min-h-8 max-h-40 w-full resize-none border-none bg-transparent px-0 py-1 text-base leading-6 text-n-slate-12 outline-none placeholder:text-n-slate-10"
      @typing-off="onTypingOff"
      @typing-on="onTypingOn"
    />
    <div class="relative flex items-center gap-0.5 py-1.5">
      <ChatAttachmentButton
        v-if="canHandleAttachments"
        class="-ms-1.5 rounded-lg text-n-slate-10 transition-colors hover:bg-n-alpha-2 hover:text-n-slate-12"
        :on-attach="onAttachFile"
      />
      <button
        v-if="shouldShowEmojiPicker && hasEmojiPickerEnabled"
        class="flex items-center justify-center min-h-8 min-w-8 rounded-lg transition-colors hover:bg-n-alpha-2"
        :class="{ '-ms-1.5': !canHandleAttachments }"
        :aria-label="$t('EMOJI.ARIA_LABEL')"
        @click="toggleEmojiPicker"
      >
        <FluentIcon
          icon="emoji"
          class="transition-colors duration-150"
          :class="showEmojiPicker ? 'text-n-brand' : 'text-n-slate-10'"
        />
      </button>
      <EmojiPicker
        v-if="shouldShowEmojiPicker && showEmojiPicker"
        v-on-clickaway="hideEmojiPicker"
        class="!bottom-full start-0 mb-2 max-w-[calc(100vw-3rem)]"
        @select="onSelectEmoji"
        @keydown.esc="hideEmojiPicker"
      />
      <ChatSendButton
        class="ms-auto"
        :disabled="!hasInput"
        @click="handleButtonClick"
      />
    </div>
  </div>
</template>

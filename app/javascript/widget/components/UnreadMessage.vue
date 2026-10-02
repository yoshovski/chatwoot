<script>
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import configMixin from '../mixins/configMixin';
import { isEmptyObject } from 'widget/helpers/utils';
import {
  ON_CAMPAIGN_MESSAGE_CLICK,
  ON_UNREAD_MESSAGE_CLICK,
} from '../constants/widgetBusEvents';
import { emitter } from 'shared/helpers/mitt';

export default {
  name: 'UnreadMessage',
  components: { Avatar },
  mixins: [configMixin],
  props: {
    message: {
      type: String,
      default: '',
    },
    showSender: {
      type: Boolean,
      default: false,
    },
    sender: {
      type: Object,
      default: () => {},
    },
    campaignId: {
      type: Number,
      default: null,
    },
    suggestedResponses: {
      type: Array,
      default: () => [],
    },
  },
  setup() {
    const { formatMessage, getPlainText, truncateMessage, highlightContent } =
      useMessageFormatter();
    return {
      formatMessage,
      getPlainText,
      truncateMessage,
      highlightContent,
    };
  },
  computed: {
    companyName() {
      return `${this.$t('UNREAD_VIEW.COMPANY_FROM')} ${
        this.channelConfig.websiteName
      }`;
    },
    avatarUrl() {
      // eslint-disable-next-line
      const displayImage = this.useInboxAvatarForBot
        ? this.inboxAvatarUrl
        : '/assets/images/chatwoot_bot.png';
      if (this.isSenderExist(this.sender)) {
        const { avatar_url: avatarUrl } = this.sender;
        return avatarUrl;
      }
      return displayImage;
    },
    agentName() {
      if (this.isSenderExist(this.sender)) {
        const { available_name: availableName, name } = this.sender;
        return availableName || name || '';
      }
      if (this.useInboxAvatarForBot) {
        return this.channelConfig.websiteName;
      }
      return this.$t('UNREAD_VIEW.BOT');
    },
    availabilityStatus() {
      if (this.isSenderExist(this.sender)) {
        const { availability_status: availabilityStatus } = this.sender;
        return availabilityStatus;
      }
      return null;
    },
  },
  methods: {
    isSenderExist(sender) {
      return sender && !isEmptyObject(sender);
    },
    onClickMessage(selectedResponse = null) {
      if (this.campaignId) {
        emitter.emit(ON_CAMPAIGN_MESSAGE_CLICK, {
          campaignId: this.campaignId,
          selectedResponse,
        });
      } else {
        emitter.emit(ON_UNREAD_MESSAGE_CLICK);
      }
    },
  },
};
</script>

<template>
  <div class="chat-bubble-wrap">
    <div
      class="chat-bubble agent overflow-hidden bg-white !p-0"
      :class="{ '!max-w-[92%]': suggestedResponses.length }"
    >
      <div v-if="showSender && !campaignId" class="row--agent-block">
        <Avatar
          :src="avatarUrl"
          :size="20"
          :name="agentName"
          :status="availabilityStatus"
          rounded-full
        />
        <span class="agent--name">{{ agentName }}</span>
        <span class="company--name">{{ companyName }}</span>
      </div>
      <button class="block w-full p-4 text-start" @click="onClickMessage()">
        <div
          v-dompurify-html="formatMessage(message, false)"
          class="message-content"
        />
      </button>
      <div
        v-if="suggestedResponses.length"
        class="mx-4 mb-4 flex flex-col border-t border-n-weak pt-2"
      >
        <button
          v-for="response in suggestedResponses"
          :key="response.id || response.title"
          type="button"
          class="flex items-center justify-between gap-3 rounded-lg px-1 py-2 text-start text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2"
          @click="onClickMessage(response)"
        >
          <span>{{ response.title }}</span>
          <i class="i-lucide-chevron-right size-4 shrink-0" />
        </button>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.chat-bubble {
  @apply max-w-[85%] cursor-pointer p-4;
}

.row--agent-block {
  @apply items-center flex text-left px-4 pt-4 text-xs;

  .agent--name {
    @apply font-medium ml-1;
  }

  .company--name {
    @apply text-n-slate-11 dark:text-n-slate-10 ml-1;
  }
}
</style>

<script>
import TeamAvailability from 'widget/components/TeamAvailability.vue';
import ConversationStarters from 'widget/components/ConversationStarters.vue';
import { mapActions, mapGetters } from 'vuex';
import { useRouter } from 'vue-router';
import { IFrameHelper } from 'widget/helpers/utils';
import { CHATWOOT_ON_START_CONVERSATION } from 'widget/constants/sdkEvents';
import configMixin from 'widget/mixins/configMixin';
import ArticleContainer from '../components/pageComponents/Home/Article/ArticleContainer.vue';
export default {
  name: 'Home',
  components: {
    ArticleContainer,
    ConversationStarters,
    TeamAvailability,
  },
  mixins: [configMixin],
  setup() {
    const router = useRouter();
    return { router };
  },
  computed: {
    ...mapGetters({
      availableAgents: 'agent/availableAgents',
      conversationSize: 'conversation/getConversationSize',
      unreadMessageCount: 'conversation/getUnreadMessageCount',
    }),
    // Matches ViewWithHeader: the branded welcome header shows only with intro text.
    hasWelcomeHeader() {
      return !!(
        this.channelConfig.welcomeTitle || this.channelConfig.welcomeTagline
      );
    },
    conversationStarters() {
      return window.chatwootWebChannel.conversationStarters || [];
    },
  },
  methods: {
    ...mapActions('conversation', ['sendMessage']),
    async startConversation(starter = '') {
      if (starter && !this.conversationSize) {
        IFrameHelper.sendMessage({
          event: 'onEvent',
          eventIdentifier: CHATWOOT_ON_START_CONVERSATION,
          data: { hasConversation: false },
        });
      }
      const starterTitle =
        typeof starter === 'object' && starter ? starter.title : starter;
      if (this.preChatFormEnabled && !this.conversationSize) {
        return this.router.replace({
          name: 'prechat-form',
          query: starterTitle ? { starter: starterTitle } : {},
        });
      }
      await this.router.replace({ name: 'messages' });
      if (starterTitle) {
        await this.sendMessage({ content: starterTitle });
      }
      return undefined;
    },
  },
};
</script>

<template>
  <div class="z-50 flex flex-col flex-1 w-full gap-4 p-4">
    <TeamAvailability
      :class="{ '-mt-14': hasWelcomeHeader }"
      :available-agents="availableAgents"
      :has-conversation="!!conversationSize"
      :unread-count="unreadMessageCount"
      @start-conversation="startConversation"
    />
    <ConversationStarters
      :starters="conversationStarters"
      @select="startConversation"
    />

    <ArticleContainer />
  </div>
</template>

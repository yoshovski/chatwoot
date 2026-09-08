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
      if (this.preChatFormEnabled && !this.conversationSize) {
        return this.router.replace({
          name: 'prechat-form',
          query: starter ? { starter } : {},
        });
      }
      await this.router.replace({ name: 'messages' });
      if (starter) {
        await this.sendMessage({ content: starter });
      }
      return undefined;
    },
  },
};
</script>

<template>
  <div class="z-50 flex flex-col justify-end flex-1 w-full p-4 gap-4">
    <ConversationStarters
      :starters="conversationStarters"
      @select="startConversation"
    />
    <TeamAvailability
      :available-agents="availableAgents"
      :has-conversation="!!conversationSize"
      :unread-count="unreadMessageCount"
      @start-conversation="startConversation"
    />

    <ArticleContainer />
  </div>
</template>

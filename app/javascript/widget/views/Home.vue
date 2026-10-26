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
      if (!this.conversationSize) {
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
  <div class="relative z-10 flex w-full flex-1 flex-col px-4 pt-4 pb-2">
    <div data-fit-content class="flex flex-col">
      <ConversationStarters
        :starters="conversationStarters"
        @select="startConversation"
      />
      <ArticleContainer />
    </div>
    <div data-home-spacer class="flex-1" />

    <div data-fit-content>
      <TeamAvailability
        :available-agents="availableAgents"
        :has-conversation="!!conversationSize"
        :unread-count="unreadMessageCount"
        @start-conversation="startConversation"
      />
    </div>

    <nav
      :aria-label="$t('WELCOME.NAVIGATION')"
      class="mt-4 grid grid-cols-2 gap-2 border-0 border-t border-solid border-n-weak pt-3"
    >
      <span
        aria-current="page"
        class="flex flex-col items-center gap-1 rounded-xl px-4 py-2 bg-n-alpha-2 text-xs font-semibold text-n-slate-12"
      >
        <i class="i-lucide-house size-5" aria-hidden="true" />
        {{ $t('WELCOME.HOME') }}
      </span>
      <button
        type="button"
        class="flex flex-col items-center gap-1 rounded-xl px-4 py-2 text-xs font-medium text-n-slate-11 transition-colors hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-slate-8"
        @click="startConversation()"
      >
        <i class="i-lucide-message-circle size-5" aria-hidden="true" />
        {{ $t('WELCOME.CHAT') }}
      </button>
    </nav>
  </div>
</template>

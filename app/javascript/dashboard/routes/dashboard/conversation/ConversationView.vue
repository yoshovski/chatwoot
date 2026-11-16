<script>
import { computed, ref } from 'vue';
import { mapGetters } from 'vuex';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAccount } from 'dashboard/composables/useAccount';
import { useConversationPaneLayout } from 'dashboard/composables/useConversationPaneLayout';
import ChatList from '../../../components/ChatList.vue';
import ConversationBox from '../../../components/widgets/conversation/ConversationBox.vue';
import wootConstants from 'dashboard/constants/globals';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import CmdBarConversationSnooze from 'dashboard/routes/dashboard/commands/CmdBarConversationSnooze.vue';
import { emitter } from 'shared/helpers/mitt';
import SidepanelSwitch from 'dashboard/components-next/Conversation/SidepanelSwitch.vue';
import ConversationSidebar from 'dashboard/components/widgets/conversation/ConversationSidebar.vue';

export default {
  components: {
    ChatList,
    ConversationBox,
    CmdBarConversationSnooze,
    SidepanelSwitch,
    ConversationSidebar,
  },
  provide() {
    return {
      conversationDetailsPanel: {
        isOpen: computed(() => this.isDetailsVisible),
        toggle: this.toggleDetails,
        close: this.closeDetails,
      },
    };
  },
  beforeRouteLeave(to, from, next) {
    // Clear selected state if navigating away from a conversation to a route without a conversationId to prevent stale data issues
    // and resolves timing issues during navigation with conversation view and other screens
    if (this.conversationId) {
      this.$store.dispatch('clearSelectedState');
    }
    next(); // Continue with navigation
  },
  props: {
    inboxId: {
      type: [String, Number],
      default: 0,
    },
    conversationId: {
      type: [String, Number],
      default: 0,
    },
    label: {
      type: String,
      default: '',
    },
    teamId: {
      type: String,
      default: '',
    },
    conversationType: {
      type: String,
      default: '',
    },
    listView: {
      type: String,
      default: '',
    },
    foldersId: {
      type: [String, Number],
      default: 0,
    },
  },
  setup() {
    const { uiSettings, updateUISettings, isOnExpandedLayout } =
      useUISettings();
    const { accountId } = useAccount();
    const sectionRef = ref(null);
    const { isSinglePane, canDockDetails } = useConversationPaneLayout(
      sectionRef,
      isOnExpandedLayout
    );

    return {
      uiSettings,
      updateUISettings,
      isOnExpandedLayout,
      accountId,
      sectionRef,
      isSinglePane,
      canDockDetails,
    };
  },
  data() {
    return {
      showSearchModal: false,
      // Opened where docking would squeeze the thread. Kept apart from the
      // saved is_contact_sidebar_open preference, which only docks the panel.
      isDetailsDrawerOpen: false,
    };
  },
  computed: {
    ...mapGetters({
      chatList: 'getAllConversations',
      currentChat: 'getSelectedChat',
    }),
    showConversationList() {
      return this.isSinglePane ? !this.conversationId : true;
    },
    showMessageView() {
      return this.conversationId ? true : !this.isSinglePane;
    },
    isDetailsVisible() {
      if (!this.currentChat.id) {
        return false;
      }
      if (!this.canDockDetails) {
        return this.isDetailsDrawerOpen;
      }
      return (
        !!this.uiSettings.is_contact_sidebar_open || this.isDetailsDrawerOpen
      );
    },
    isDetailsDrawer() {
      return !this.canDockDetails;
    },
  },
  watch: {
    conversationId() {
      this.fetchConversationIfUnavailable();
      this.isDetailsDrawerOpen = false;
    },
  },

  created() {
    // Clear selected state early if no conversation is selected
    // This prevents child components from accessing stale data
    // and resolves timing issues during navigation
    // with conversation view and other screens
    if (!this.conversationId) {
      this.$store.dispatch('clearSelectedState');
    }
  },

  mounted() {
    this.$store.dispatch('agents/get');
    this.$store.dispatch('portals/index');
    this.initialize();
    this.$watch('$store.state.route', () => this.initialize());
    this.$watch('chatList.length', () => {
      this.setActiveChat();
    });
  },

  methods: {
    onConversationLoad() {
      this.fetchConversationIfUnavailable();
    },
    initialize() {
      this.$store.dispatch('setActiveInbox', this.inboxId);
      this.setActiveChat();
    },
    toggleConversationLayout() {
      const { LAYOUT_TYPES } = wootConstants;
      const {
        conversation_display_type:
          conversationDisplayType = LAYOUT_TYPES.CONDENSED,
      } = this.uiSettings;
      const newViewType =
        conversationDisplayType === LAYOUT_TYPES.CONDENSED
          ? LAYOUT_TYPES.EXPANDED
          : LAYOUT_TYPES.CONDENSED;
      this.updateUISettings({
        conversation_display_type: newViewType,
        previously_used_conversation_display_type: newViewType,
      });
    },
    fetchConversationIfUnavailable() {
      if (!this.conversationId) {
        return;
      }
      const chat = this.findConversation();
      if (!chat) {
        this.$store.dispatch('getConversation', this.conversationId);
      }
    },
    findConversation() {
      const conversationId = parseInt(this.conversationId, 10);
      const [chat] = this.chatList.filter(c => c.id === conversationId);
      return chat;
    },
    setActiveChat() {
      if (this.conversationId) {
        const selectedConversation = this.findConversation();
        // If conversation doesn't exist or selected conversation is same as the active
        // conversation, don't set active conversation.
        if (
          !selectedConversation ||
          selectedConversation.id === this.currentChat.id
        ) {
          return;
        }
        const { messageId } = this.$route.query;
        this.$store
          .dispatch('setActiveChat', {
            data: selectedConversation,
            after: messageId,
          })
          .then(() => {
            emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE, { messageId });
          });
      } else {
        this.$store.dispatch('clearSelectedState');
      }
    },
    toggleDetails() {
      if (this.isDetailsDrawer) {
        this.isDetailsDrawerOpen = !this.isDetailsDrawerOpen;
        return;
      }
      const isVisible = this.isDetailsVisible;
      this.isDetailsDrawerOpen = false;
      this.updateUISettings({
        is_contact_sidebar_open: !isVisible,
        is_copilot_panel_open: false,
      });
    },
    closeDetails() {
      if (this.isDetailsVisible) this.toggleDetails();
    },
    onSearch() {
      this.showSearchModal = true;
    },
    closeSearch() {
      this.showSearchModal = false;
    },
  },
};
</script>

<template>
  <!-- List and thread share one card, split by a line, so the thread gets the
  width; the customer panel sits beside it on the tinted background. Panes that
  would squeeze the thread give way: the list hides behind Back and the
  customer panel floats as a drawer (see useConversationPaneLayout). -->
  <section
    ref="sectionRef"
    class="relative flex w-full h-full min-w-0 gap-3 p-3 bg-n-background"
  >
    <div
      class="flex min-w-0 flex-1 overflow-hidden rounded-card bg-n-solid-2 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
    >
      <ChatList
        :show-conversation-list="showConversationList"
        :conversation-inbox="inboxId"
        :label="label"
        :team-id="teamId"
        :conversation-type="conversationType"
        :list-view="listView"
        :folders-id="foldersId"
        :is-on-expanded-layout="isOnExpandedLayout"
        :is-single-pane="isSinglePane"
        @conversation-load="onConversationLoad"
      />
      <ConversationBox
        v-if="showMessageView"
        class="!rounded-none !shadow-none"
        :inbox-id="inboxId"
        :is-on-expanded-layout="isSinglePane"
      >
        <SidepanelSwitch v-if="currentChat.id" />
      </ConversationBox>
    </div>
    <ConversationSidebar
      v-if="isDetailsVisible"
      :current-chat="currentChat"
      :is-drawer="isDetailsDrawer"
      @close="closeDetails"
    />
    <CmdBarConversationSnooze />
  </section>
</template>

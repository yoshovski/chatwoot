<script>
import Banner from '../Banner.vue';
import Branding from 'shared/components/Branding.vue';
import ChatHeader from '../ChatHeader.vue';
import ChatHeaderExpanded from '../ChatHeaderExpanded.vue';
import configMixin from '../../mixins/configMixin';
import { mapGetters } from 'vuex';
import { IFrameHelper } from 'widget/helpers/utils';

export default {
  components: {
    Banner,
    Branding,
    ChatHeader,
    ChatHeaderExpanded,
  },
  mixins: [configMixin],
  data() {
    return {
      showPopoutButton: false,
      scrollPosition: 0,
      ticking: true,
      disableBranding: window.chatwootWebChannel.disableBranding || false,
      requestID: null,
      homeResizeObserver: null,
    };
  },
  computed: {
    ...mapGetters({
      appConfig: 'appConfig/getAppConfig',
      availableAgents: 'agent/availableAgents',
    }),
    portal() {
      return window.chatwootWebChannel.portal;
    },
    isHeaderCollapsed() {
      return !this.isOnHomeView;
    },
    showBackButton() {
      return ['article-viewer', 'messages', 'prechat-form'].includes(
        this.$route.name
      );
    },
    isOnArticleViewer() {
      return ['article-viewer'].includes(this.$route.name);
    },
    isOnHomeView() {
      return ['home'].includes(this.$route.name);
    },
    opacityClass() {
      if (this.isHeaderCollapsed) {
        return {};
      }
      if (this.scrollPosition > 30) {
        return { 'opacity-30': true };
      }
      if (this.scrollPosition > 25) {
        return { 'opacity-40': true };
      }
      if (this.scrollPosition > 20) {
        return { 'opacity-60': true };
      }
      if (this.scrollPosition > 15) {
        return { 'opacity-80': true };
      }
      if (this.scrollPosition > 10) {
        return { 'opacity-90': true };
      }
      return {};
    },
  },
  watch: {
    isOnHomeView() {
      this.$nextTick(this.fitHomeHeight);
    },
  },
  mounted() {
    this.$el.addEventListener('scroll', this.updateScrollPosition);
    this.fitHomeHeight();
  },
  unmounted() {
    this.$el.removeEventListener('scroll', this.updateScrollPosition);
    cancelAnimationFrame(this.requestID);
    this.homeResizeObserver?.disconnect();
  },
  methods: {
    closeWindow() {
      IFrameHelper.sendMessage({ event: 'closeWindow' });
    },
    // The home screen asks the SDK to shrink the window to its content; other views use the full height.
    fitHomeHeight() {
      this.homeResizeObserver?.disconnect();
      if (!this.isOnHomeView) {
        IFrameHelper.sendMessage({ event: 'setContentHeight', height: null });
        return;
      }
      const { content } = this.$refs;
      this.homeResizeObserver = new ResizeObserver(() => {
        const spacer = content.querySelector('[data-home-spacer]');
        IFrameHelper.sendMessage({
          event: 'setContentHeight',
          height: content.offsetHeight - (spacer?.offsetHeight || 0),
        });
      });
      [content, ...content.querySelectorAll('[data-fit-content]')].forEach(
        element => this.homeResizeObserver.observe(element)
      );
    },
    updateScrollPosition(event) {
      this.scrollPosition = event.target.scrollTop;
      if (!this.ticking) {
        this.requestID = window.requestAnimationFrame(() => {
          this.ticking = false;
        });

        this.ticking = true;
      }
    },
  },
};
</script>

<template>
  <div
    class="w-full h-full bg-n-solid-1 [&_.chat-bubble]:!shadow-none"
    :class="{ 'overflow-auto': isOnHomeView }"
    @keydown.esc="closeWindow"
  >
    <div
      ref="content"
      class="relative flex flex-col min-h-full"
      :class="{ 'h-full': !isOnHomeView }"
    >
      <div
        data-fit-content
        :class="{
          expanded: !isHeaderCollapsed,
          collapsed: isHeaderCollapsed,
          'shadow-[0_10px_15px_-16px_rgba(50,50,93,0.08),0_4px_6px_-8px_rgba(50,50,93,0.04)]':
            isHeaderCollapsed,
          ...opacityClass,
        }"
      >
        <ChatHeaderExpanded
          v-if="!isHeaderCollapsed"
          :intro-heading="
            appConfig.welcomeTitle ||
            channelConfig.welcomeTitle ||
            $t('WELCOME.TITLE')
          "
          :intro-body="
            appConfig.welcomeDescription ||
            channelConfig.welcomeTagline ||
            $t('WELCOME.DESCRIPTION')
          "
          :avatar-url="channelConfig.avatarUrl"
          :website-name="channelConfig.websiteName"
          :show-popout-button="appConfig.showPopoutButton"
        />
        <ChatHeader
          v-if="isHeaderCollapsed"
          :title="channelConfig.websiteName"
          :avatar-url="channelConfig.avatarUrl"
          :show-popout-button="appConfig.showPopoutButton"
          :available-agents="availableAgents"
          :show-back-button="showBackButton"
        />
      </div>
      <Banner />
      <router-view />

      <Branding v-if="!isOnArticleViewer" :disable-branding="disableBranding" />
    </div>
  </div>
</template>

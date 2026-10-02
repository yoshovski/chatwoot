<script>
import { mapGetters } from 'vuex';
import { IFrameHelper } from 'widget/helpers/utils';
import { shouldOutlineWidgetButton } from 'shared/helpers/colorHelper';

export default {
  components: {},
  props: {
    action: {
      type: Object,
      default: () => {},
    },
  },
  computed: {
    ...mapGetters({
      widgetColor: 'appConfig/getWidgetColor',
      widgetTextColor: 'appConfig/getWidgetTextColor',
    }),
    isLink() {
      return this.action.type === 'link';
    },
    isOutlined() {
      return shouldOutlineWidgetButton(this.widgetColor);
    },
    buttonStyle() {
      if (this.isOutlined) {
        return undefined;
      }

      return {
        background: this.widgetColor,
        borderColor: this.widgetColor,
        color: this.widgetTextColor,
      };
    },
  },
  methods: {
    onClick() {
      if (this.action.type === 'postback') {
        // Send message to parent iframe
        if (IFrameHelper.isIFrame()) {
          IFrameHelper.sendMessage({
            event: 'postback',
            data: { payload: this.action.payload },
          });
        }
      }
    },
  },
};
</script>

<template>
  <a
    v-if="isLink"
    :key="action.uri"
    class="action-button button"
    :class="{ 'is-outlined': isOutlined }"
    :href="action.uri"
    :style="buttonStyle"
    target="_blank"
    rel="noopener nofollow noreferrer"
  >
    {{ action.text }}
  </a>
  <button
    v-else
    :key="action.payload"
    class="action-button button"
    :class="{ 'is-outlined': isOutlined }"
    :style="buttonStyle"
    @click="onClick"
  >
    {{ action.text }}
  </button>
</template>

<style scoped lang="scss">
.action-button {
  @apply items-center rounded-lg flex font-medium justify-center mt-1 p-0 w-full;
}
</style>

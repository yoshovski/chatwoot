<script>
import { mapGetters } from 'vuex';

export default {
  components: {},
  props: {
    action: {
      type: Object,
      default: () => {},
    },
    isSelected: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['optionSelect'],
  computed: {
    ...mapGetters({
      widgetColor: 'appConfig/getWidgetColor',
      widgetTextColor: 'appConfig/getWidgetTextColor',
    }),
  },
  methods: {
    onClick() {
      this.$emit('optionSelect', this.action);
    },
  },
};
</script>

<template>
  <li
    class="option"
    :class="{ 'is-selected': isSelected }"
    :style="isSelected ? { backgroundColor: widgetColor } : undefined"
  >
    <button class="option-button" @click="onClick">
      <span
        class="text-n-slate-12"
        :style="isSelected ? { color: widgetTextColor } : undefined"
      >
        {{ action.title }}
      </span>
    </button>
  </li>
</template>

<style scoped lang="scss">
.option {
  @apply rounded-full border border-solid border-n-strong m-0 max-w-full bg-n-background text-n-slate-12 transition-colors;

  // The hover has to live here rather than as utility classes on the element: both carry the same
  // specificity as this rule, and the scoped stylesheet is injected last, so it wins.
  &:hover:not(.is-selected) {
    @apply bg-n-slate-3 border-n-slate-8;
  }

  .option-button {
    @apply bg-transparent border-0 cursor-pointer h-auto text-sm leading-snug text-start whitespace-normal rounded-full px-3.5 py-1.5;

    span {
      display: inline-block;
      vertical-align: middle;
    }
  }
}
</style>

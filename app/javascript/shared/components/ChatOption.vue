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
    <button class="option-button button" @click="onClick">
      <span :style="isSelected ? { color: widgetTextColor } : undefined">
        {{ action.title }}
      </span>
    </button>
  </li>
</template>

<style scoped lang="scss">
.option {
  @apply rounded-xl border border-solid border-n-strong m-0 max-w-full bg-n-background text-n-slate-12;

  .option-button {
    @apply bg-transparent border-0 cursor-pointer h-auto leading-normal text-center whitespace-normal rounded-xl min-h-[2.75rem] px-4 py-2.5;

    span {
      display: inline-block;
      vertical-align: middle;
    }
  }
}
</style>

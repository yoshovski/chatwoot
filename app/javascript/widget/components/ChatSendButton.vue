<script>
import Spinner from 'shared/components/Spinner.vue';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';

export default {
  components: {
    FluentIcon,
    Spinner,
  },
  props: {
    loading: {
      type: Boolean,
      default: false,
    },
    disabled: {
      type: Boolean,
      default: false,
    },
  },
};
</script>

<template>
  <button
    type="submit"
    :disabled="disabled"
    :aria-label="$t('SEND_MESSAGE')"
    class="flex size-9 shrink-0 items-center justify-center rounded-full transition-colors duration-200"
    :class="
      disabled
        ? 'bg-n-alpha-2 text-n-slate-9'
        : 'bg-[var(--widget-color)] text-[var(--widget-text-color)] hover:opacity-90'
    "
  >
    <FluentIcon
      v-if="!loading"
      icon="send"
      size="18"
      class="rtl:-scale-x-100"
    />
    <Spinner v-else size="small" />
  </button>
</template>

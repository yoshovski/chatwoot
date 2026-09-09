<script>
import Spinner from 'shared/components/Spinner.vue';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import { shouldOutlineWidgetButton } from 'shared/helpers/colorHelper';

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
    color: {
      type: String,
      default: '#6e6f73',
    },
  },
  computed: {
    // The icon sits on the composer, which is near-white. A widget colour light enough to
    // disappear into a message bubble disappears here too, so it falls back to the default.
    iconColor() {
      return shouldOutlineWidgetButton(this.color) ? null : this.color;
    },
  },
};
</script>

<template>
  <button
    type="submit"
    :disabled="disabled"
    class="min-h-8 min-w-8 flex items-center justify-center ml-1"
  >
    <FluentIcon
      v-if="!loading"
      icon="send"
      class="text-n-slate-11"
      :style="iconColor ? `color: ${iconColor}` : undefined"
    />
    <Spinner v-else size="small" />
  </button>
</template>

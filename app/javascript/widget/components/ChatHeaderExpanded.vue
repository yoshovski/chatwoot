<script setup>
import HeaderActions from './HeaderActions.vue';
import { computed } from 'vue';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { useMapGetter } from 'dashboard/composables/store.js';

const props = defineProps({
  avatarUrl: {
    type: String,
    default: '',
  },
  introHeading: {
    type: String,
    default: '',
  },
  introBody: {
    type: String,
    default: '',
  },
  showPopoutButton: {
    type: Boolean,
    default: false,
  },
});

const { formatMessage } = useMessageFormatter();
const widgetColor = useMapGetter('appConfig/getWidgetColor');
const widgetTextColor = useMapGetter('appConfig/getWidgetTextColor');

const containerClasses = computed(() => [
  props.avatarUrl ? 'justify-between' : 'justify-end',
]);
</script>

<template>
  <!-- Brand-coloured welcome area; the home card overlaps its lower edge. -->
  <header
    class="header-expanded relative box-border w-full px-5 pt-6 pb-16 [&_.actions_svg]:!text-current"
    :style="{ backgroundColor: widgetColor, color: widgetTextColor }"
  >
    <div class="flex items-start" :class="containerClasses">
      <img
        v-if="avatarUrl"
        class="object-cover size-12 rounded-xl bg-white"
        :src="avatarUrl"
        alt="Avatar"
      />
      <HeaderActions
        :show-popout-button="showPopoutButton"
        :show-end-conversation-button="false"
      />
    </div>
    <h2
      v-dompurify-html="introHeading"
      class="mt-12 mb-2 text-3xl font-semibold leading-tight line-clamp-4"
    />
    <p
      v-dompurify-html="formatMessage(introBody)"
      class="text-lg leading-normal opacity-90 [&_a]:underline line-clamp-6"
    />
  </header>
</template>

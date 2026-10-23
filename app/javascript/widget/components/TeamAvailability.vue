<script setup>
import { IFrameHelper } from 'widget/helpers/utils';
import { CHATWOOT_ON_START_CONVERSATION } from '../constants/sdkEvents';
import AvailabilityContainer from 'widget/components/Availability/AvailabilityContainer.vue';
import { useMapGetter } from 'dashboard/composables/store.js';

const props = defineProps({
  availableAgents: { type: Array, default: () => [] },
  hasConversation: { type: Boolean, default: false },
});

const emit = defineEmits(['startConversation']);

const widgetColor = useMapGetter('appConfig/getWidgetColor');
const widgetTextColor = useMapGetter('appConfig/getWidgetTextColor');

const startConversation = () => {
  emit('startConversation');
  if (!props.hasConversation) {
    IFrameHelper.sendMessage({
      event: 'onEvent',
      eventIdentifier: CHATWOOT_ON_START_CONVERSATION,
      data: { hasConversation: false },
    });
  }
};
</script>

<template>
  <button
    type="button"
    class="relative flex items-center justify-between w-full gap-4 px-5 py-4 transition-shadow shadow-sm text-start rounded-xl bg-n-solid-1 dark:bg-n-solid-2 outline outline-1 outline-n-weak hover:shadow-md focus-visible:outline-2 focus-visible:outline-n-slate-8"
    @click="startConversation"
  >
    <div class="flex flex-col min-w-0 gap-1">
      <span class="text-base font-medium text-n-slate-12">
        {{
          hasConversation
            ? $t('CONTINUE_CONVERSATION')
            : $t('START_CONVERSATION')
        }}
      </span>
      <AvailabilityContainer
        :agents="availableAgents"
        :show-header="false"
        :show-avatars="false"
        text-classes="text-sm"
      />
    </div>
    <span
      class="flex items-center justify-center rounded-full shrink-0 size-10"
      :style="{ backgroundColor: widgetColor, color: widgetTextColor }"
    >
      <i class="i-lucide-send-horizontal size-5 rtl:rotate-180" />
    </span>
  </button>
</template>

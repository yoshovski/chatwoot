<script setup>
import { computed } from 'vue';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import AvailabilityContainer from 'widget/components/Availability/AvailabilityContainer.vue';
import { useMapGetter } from 'dashboard/composables/store.js';

const props = defineProps({
  availableAgents: { type: Array, default: () => [] },
  hasConversation: { type: Boolean, default: false },
  unreadCount: { type: Number, default: 0 },
});

const emit = defineEmits(['startConversation']);

const lastMessage = useMapGetter('conversation/getLastMessage');
const { getPlainText } = useMessageFormatter();
const preview = computed(() =>
  props.hasConversation ? getPlainText(lastMessage.value?.content || '') : ''
);

const startConversation = () => {
  emit('startConversation');
};
</script>

<template>
  <button
    type="button"
    class="group relative flex w-full items-center justify-between gap-4 rounded-2xl bg-n-solid-1 p-4 text-start outline outline-1 outline-n-weak transition-colors hover:bg-n-alpha-1 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-slate-8 dark:bg-n-solid-2"
    @click="startConversation"
  >
    <div class="flex flex-col min-w-0 gap-1">
      <span
        class="flex items-center gap-2 text-base font-semibold text-n-slate-12"
      >
        {{
          hasConversation
            ? $t('CONTINUE_CONVERSATION')
            : $t('START_CONVERSATION')
        }}
        <span
          v-if="unreadCount"
          class="flex min-w-5 h-5 shrink-0 items-center justify-center rounded-full bg-[var(--widget-color)] px-1 text-xs text-[var(--widget-text-color)]"
          :aria-label="$t('VIEW_UNREAD_MESSAGES')"
        >
          {{ unreadCount }}
        </span>
      </span>
      <span
        v-if="preview"
        class="line-clamp-1 break-words text-sm leading-relaxed text-n-slate-11"
      >
        {{ preview }}
      </span>
      <span
        v-else-if="!hasConversation"
        class="text-sm leading-relaxed text-n-slate-11"
      >
        {{ $t('WELCOME.CHAT_DESCRIPTION') }}
      </span>
      <AvailabilityContainer
        :agents="availableAgents"
        :show-header="false"
        :show-avatars="false"
        text-classes="text-xs"
        class="mt-2"
      />
    </div>
    <span
      class="flex size-10 shrink-0 items-center justify-center rounded-xl bg-[var(--widget-color)] text-[var(--widget-text-color)] transition-transform group-hover:translate-x-0.5 rtl:group-hover:-translate-x-0.5"
    >
      <i class="i-lucide-arrow-right size-5 rtl:rotate-180" />
    </span>
  </button>
</template>

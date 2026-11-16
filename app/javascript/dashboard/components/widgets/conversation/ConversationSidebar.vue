<script setup>
import { nextTick, onBeforeUnmount, ref, watch } from 'vue';
import ContactPanel from 'dashboard/routes/dashboard/conversation/ContactPanel.vue';

const props = defineProps({
  currentChat: {
    required: true,
    type: Object,
  },
  // Floats over the thread instead of sitting beside it, where docking would
  // leave the thread too narrow to read.
  isDrawer: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['close']);

const panelRef = ref(null);
let focusBeforeDrawer = null;

const restoreFocus = () => {
  if (focusBeforeDrawer?.isConnected) focusBeforeDrawer.focus();
  focusBeforeDrawer = null;
};

watch(
  () => props.isDrawer,
  async isDrawer => {
    if (!isDrawer) {
      focusBeforeDrawer = null;
      return;
    }
    focusBeforeDrawer = document.activeElement;
    await nextTick();
    panelRef.value?.focus();
  },
  { immediate: true }
);

onBeforeUnmount(() => {
  if (props.isDrawer) restoreFocus();
});
</script>

<template>
  <div
    v-if="isDrawer"
    class="absolute inset-0 z-30 bg-n-alpha-black2"
    @click="emit('close')"
  />
  <div
    ref="panelRef"
    data-conversation-details
    :role="isDrawer ? 'dialog' : 'complementary'"
    :aria-label="$t('CONVERSATION.SIDEBAR.CONTACT')"
    tabindex="-1"
    class="flex flex-col h-full overflow-hidden outline-none"
    :class="
      isDrawer
        ? 'absolute inset-y-0 end-0 z-40 w-full max-w-sm p-3 bg-n-background shadow-lg'
        : 'w-[21rem] min-w-[21rem] xl:w-[22rem] xl:min-w-[22rem]'
    "
    @keydown.esc.stop="isDrawer && emit('close')"
  >
    <div class="flex flex-col flex-1 min-h-0 overflow-hidden">
      <ContactPanel
        :conversation-id="currentChat.id"
        :inbox-id="currentChat.inbox_id"
      />
    </div>
  </div>
</template>

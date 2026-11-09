<script setup>
import { computed, ref, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import SidePanel from 'dashboard/components-next/side-panel/SidePanel.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { getInboxIconByType } from 'dashboard/helper/inbox';

const props = defineProps({
  assistantId: {
    type: Number,
    required: true,
  },
  assistantName: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['connected']);

const open = defineModel('open', { type: Boolean, default: false });

const { t } = useI18n();
const route = useRoute();
const store = useStore();
const sidePanelRef = ref(null);

const accountId = computed(() => route.params.accountId);
const allInboxes = useMapGetter('inboxes/getInboxes');
const captainInboxes = useMapGetter('captainInboxes/getRecords');
const connectingInboxId = ref(null);

watch(open, isOpen => {
  if (isOpen) {
    sidePanelRef.value?.open();
    store.dispatch('inboxes/get');
  } else {
    sidePanelRef.value?.close();
  }
});

const availableInboxes = computed(() => {
  const connectedIds = (captainInboxes.value || []).map(i => i.id);
  return (allInboxes.value || []).filter(i => !connectedIds.includes(i.id));
});

const getChannelTypeLabel = inbox => {
  if (inbox.channel_type === 'Channel::WebWidget')
    return t('CAPTAIN.INBOXES.TYPES.WEB');
  if (inbox.channel_type === 'Channel::Email')
    return t('CAPTAIN.INBOXES.TYPES.EMAIL');
  if (inbox.channel_type === 'Channel::Whatsapp')
    return t('CAPTAIN.INBOXES.TYPES.WHATSAPP');
  if (inbox.channel_type === 'Channel::TwilioSms')
    return t('CAPTAIN.INBOXES.TYPES.SMS');
  return (
    inbox.channel_type?.replace('Channel::', '') ||
    t('CAPTAIN.INBOXES.TYPES.CHANNEL')
  );
};

const getInboxIcon = inbox => {
  return getInboxIconByType(
    inbox.channel_type,
    inbox.medium,
    'outline',
    inbox.voice_enabled
  );
};

const handleConnect = async inboxId => {
  connectingInboxId.value = inboxId;
  try {
    await store.dispatch('captainInboxes/create', {
      assistantId: props.assistantId,
      inboxId,
    });
    useAlert(t('CAPTAIN.INBOXES.CREATE.SUCCESS_MESSAGE'));
    emit('connected', inboxId);
    if (availableInboxes.value.length <= 1) {
      open.value = false;
    }
  } catch (error) {
    useAlert(error?.message || t('CAPTAIN.INBOXES.CREATE.ERROR_MESSAGE'));
  } finally {
    connectingInboxId.value = null;
  }
};
</script>

<template>
  <SidePanel
    ref="sidePanelRef"
    :title="t('CAPTAIN.INBOXES.CREATE.TITLE')"
    :description="
      t('CAPTAIN.INBOXES.CREATE.DESCRIPTION', {
        name: assistantName || 'the AI agent',
      })
    "
    width="lg"
    @close="open = false"
  >
    <div class="flex flex-col gap-4">
      <div v-if="availableInboxes.length" class="flex flex-col gap-3">
        <div
          v-for="inbox in availableInboxes"
          :key="inbox.id"
          class="flex items-center justify-between p-3.5 rounded-xl border border-n-weak bg-n-solid-1 gap-3"
        >
          <div class="flex items-center gap-3 min-w-0">
            <span
              class="flex items-center justify-center rounded-lg size-10 shrink-0 bg-n-alpha-2 text-n-slate-11"
              aria-hidden="true"
            >
              <span :class="getInboxIcon(inbox)" class="size-5" />
            </span>
            <div class="flex flex-col min-w-0">
              <span class="text-sm font-medium text-n-slate-12 truncate">
                {{ inbox.name }}
              </span>
              <span class="text-xs text-n-slate-11 truncate">
                {{ getChannelTypeLabel(inbox) }}
              </span>
            </div>
          </div>
          <Button
            type="button"
            size="sm"
            :label="t('CAPTAIN.INBOXES.CREATE.CONNECT_BUTTON')"
            :is-loading="connectingInboxId === inbox.id"
            :disabled="connectingInboxId !== null"
            @click="handleConnect(inbox.id)"
          />
        </div>
      </div>

      <div
        v-else
        class="flex flex-col items-center justify-center py-10 px-4 text-center gap-3"
      >
        <span
          class="flex items-center justify-center rounded-full size-12 bg-n-teal-3 text-n-teal-11 dark:bg-n-teal-11/20 dark:text-n-teal-7"
        >
          <span class="i-lucide-check-check size-6" />
        </span>
        <div class="flex flex-col gap-1 max-w-sm">
          <h3 class="text-base font-semibold text-n-slate-12">
            {{ t('CAPTAIN.INBOXES.CREATE.ALL_CONNECTED_TITLE') }}
          </h3>
          <p class="text-sm text-n-slate-11">
            {{
              t('CAPTAIN.INBOXES.CREATE.ALL_CONNECTED_DESC', {
                name: assistantName || 'this AI agent',
              })
            }}
          </p>
        </div>
        <router-link
          :to="`/app/accounts/${accountId}/settings/inboxes/new`"
          class="inline-flex items-center gap-1.5 text-sm font-medium text-n-brand hover:underline mt-2"
        >
          <span>{{ t('CAPTAIN.INBOXES.CREATE.CREATE_NEW_INBOX') }}</span>
          <span class="i-lucide-arrow-right size-4" />
        </router-link>
      </div>
    </div>

    <template #footer>
      <div class="flex justify-end">
        <Button
          type="button"
          variant="faded"
          color="slate"
          :label="t('CAPTAIN.AGENT_UX.DONE')"
          @click="open = false"
        />
      </div>
    </template>
  </SidePanel>
</template>

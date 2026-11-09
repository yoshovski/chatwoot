<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Policy from 'dashboard/components/policy.vue';
import { INBOX_TYPES, getInboxIconByType } from 'dashboard/helper/inbox';

const props = defineProps({
  id: {
    type: Number,
    required: true,
  },
  inbox: {
    type: Object,
    required: true,
  },
  assistant: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['action']);

const { t } = useI18n();

const inboxName = computed(() => {
  const inbox = props.inbox;
  if (!inbox?.name) {
    return '';
  }

  const isTwilioChannel = inbox.channel_type === INBOX_TYPES.TWILIO;
  const isWhatsAppChannel = inbox.channel_type === INBOX_TYPES.WHATSAPP;
  const isEmailChannel = inbox.channel_type === INBOX_TYPES.EMAIL;

  if (isTwilioChannel || isWhatsAppChannel) {
    const identifier = inbox.messaging_service_sid || inbox.phone_number;
    return identifier ? `${inbox.name} (${identifier})` : inbox.name;
  }

  if (isEmailChannel && inbox.email) {
    return `${inbox.name} (${inbox.email})`;
  }

  return inbox.name;
});

const channelLabel = computed(() => {
  const type = props.inbox?.channel_type;
  if (type === 'Channel::WebWidget') return t('CAPTAIN.INBOXES.TYPES.WEB');
  if (type === 'Channel::Email') return t('CAPTAIN.INBOXES.TYPES.EMAIL');
  if (type === 'Channel::Whatsapp') return t('CAPTAIN.INBOXES.TYPES.WHATSAPP');
  if (type === 'Channel::TwilioSms') return t('CAPTAIN.INBOXES.TYPES.SMS');
  return type?.replace('Channel::', '') || t('CAPTAIN.INBOXES.TYPES.CHANNEL');
});

const scheduleSummary = computed(() => {
  const windowType = props.assistant?.config?.response_window || 'always';
  return t(
    `CAPTAIN.ASSISTANTS.FORM.SCHEDULE.${windowType.toUpperCase()}.LABEL`
  );
});

const audienceSummary = computed(() => {
  const hasAudience = !!props.assistant?.config?.audience;
  return hasAudience
    ? t('CAPTAIN.ASSISTANTS.FORM.AUDIENCE.SPECIFIC.LABEL')
    : t('CAPTAIN.ASSISTANTS.FORM.AUDIENCE.EVERYONE.LABEL');
});

const icon = computed(() => {
  const {
    medium,
    channel_type: type,
    voice_enabled: voiceEnabled,
  } = props.inbox;
  return getInboxIconByType(type, medium, 'outline', voiceEnabled);
});

const handleDisconnect = () => {
  emit('action', { action: 'delete', id: props.id });
};
</script>

<template>
  <CardLayout class="p-4 sm:p-5">
    <div
      class="flex flex-col sm:flex-row sm:items-center justify-between w-full gap-3 sm:gap-4"
    >
      <div class="flex items-start gap-3 min-w-0">
        <span
          class="flex items-center justify-center rounded-lg size-10 shrink-0 bg-n-alpha-2 text-n-slate-11 mt-0.5 sm:mt-0"
          aria-hidden="true"
        >
          <span :class="icon" class="size-5" />
        </span>
        <div class="flex flex-col min-w-0 gap-1">
          <div class="flex flex-wrap items-center gap-2">
            <span class="text-base font-medium text-n-slate-12 truncate">
              {{ inboxName }}
            </span>
            <span
              class="px-2 py-0.5 text-xs rounded-md bg-n-alpha-2 text-n-slate-11 font-medium"
            >
              {{ channelLabel }}
            </span>
            <span
              class="inline-flex items-center gap-1.5 px-2 py-0.5 text-xs rounded-full font-medium bg-n-teal-3 text-n-teal-11 dark:bg-n-teal-11/20 dark:text-n-teal-7"
            >
              <span class="size-1.5 rounded-full bg-n-teal-9 animate-pulse" />
              {{ t('CAPTAIN.INBOXES.STATUS.ACTIVE') }}
            </span>
          </div>
          <p
            class="m-0 text-xs text-n-slate-11 flex flex-wrap items-center gap-x-1.5 gap-y-0.5"
          >
            <span>{{ t('CAPTAIN.INBOXES.REPLIES_FOLLOW') }}</span>
            <span class="font-medium text-n-slate-12">{{
              scheduleSummary
            }}</span>
            <span>·</span>
            <span class="font-medium text-n-slate-12">{{
              audienceSummary
            }}</span>
          </p>
        </div>
      </div>
      <div class="flex items-center gap-2 shrink-0 self-end sm:self-center">
        <Policy :permissions="['administrator']">
          <Button
            type="button"
            icon="i-lucide-power"
            variant="faded"
            color="slate"
            size="sm"
            :label="t('CAPTAIN.INBOXES.OPTIONS.DISCONNECT')"
            @click="handleDisconnect"
          />
        </Policy>
      </div>
    </div>
  </CardLayout>
</template>

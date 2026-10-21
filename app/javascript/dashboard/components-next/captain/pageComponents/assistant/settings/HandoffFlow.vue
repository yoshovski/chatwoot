<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import FlowSteps from './FlowSteps.vue';

const props = defineProps({
  name: { type: String, default: '' },
  message: { type: String, default: '' },
  fallbackTeam: { type: String, default: '' },
  fallbackAgent: { type: String, default: '' },
  keepHelping: { type: Boolean, default: false },
  safetyNet: { type: Boolean, default: false },
});

const { t } = useI18n();

const fallbackLabel = computed(() =>
  [props.fallbackTeam, props.fallbackAgent].filter(Boolean).join(' / ')
);

const steps = computed(() => [
  {
    key: 'trigger',
    icon: 'i-lucide-hand',
    tone: 'blue',
    title: t(
      props.safetyNet
        ? 'CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.FLOW.TRIGGER_OR_STUCK'
        : 'CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.FLOW.TRIGGER',
      {
        name: props.name,
      }
    ),
  },
  {
    key: 'message',
    icon: 'i-lucide-message-circle',
    tone: 'slate',
    title: t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.FLOW.SAYS', {
      name: props.name,
    }),
    detail:
      props.message?.trim() ||
      t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.FLOW.DEFAULT_MESSAGE'),
    quote: true,
  },
  {
    key: 'assign',
    icon: 'i-lucide-users',
    tone: 'teal',
    title: t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.FLOW.ASSIGN'),
    detail: fallbackLabel.value
      ? t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.FLOW.FALLBACK', {
          assignee: fallbackLabel.value,
        })
      : t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.FLOW.NO_FALLBACK'),
  },
  {
    key: 'waiting',
    icon: props.keepHelping
      ? 'i-lucide-bot-message-square'
      : 'i-lucide-hourglass',
    tone: props.keepHelping ? 'blue' : 'amber',
    title: t(
      props.keepHelping
        ? 'CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.FLOW.KEEPS_HELPING'
        : 'CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.FLOW.WAITS',
      {
        name: props.name,
      }
    ),
  },
]);
</script>

<template>
  <FlowSteps
    :title="t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.FLOW.TITLE')"
    :steps="steps"
  />
</template>

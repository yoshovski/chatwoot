<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import FlowSteps from './FlowSteps.vue';

const props = defineProps({
  name: { type: String, default: '' },
  // Matches config.auto_resolve_mode: evaluated | legacy | disabled
  mode: { type: String, default: 'evaluated' },
  minutes: { type: Number, default: 60 },
  goodbye: { type: String, default: '' },
  sendGoodbye: { type: Boolean, default: false },
});

const { t } = useI18n();

const duration = computed(() => {
  const hours = Math.floor(props.minutes / 60);
  const minutes = props.minutes % 60;
  return [
    hours
      ? t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.FLOW.HOURS', { count: hours })
      : '',
    minutes
      ? t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.FLOW.MINUTES', {
          count: minutes,
        })
      : '',
  ]
    .filter(Boolean)
    .join(' ');
});

const goodbyeStep = computed(() =>
  props.sendGoodbye
    ? [
        {
          key: 'goodbye',
          icon: 'i-lucide-message-circle',
          tone: 'slate',
          title: t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.FLOW.SAYS_GOODBYE', {
            name: props.name,
          }),
          detail:
            props.goodbye?.trim() ||
            t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.FLOW.DEFAULT_GOODBYE'),
          quote: true,
        },
      ]
    : []
);

const steps = computed(() => {
  const start = {
    key: 'quiet',
    icon: 'i-lucide-message-square-off',
    tone: 'blue',
    title: t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.FLOW.QUIET'),
  };
  if (props.mode === 'disabled') {
    return [
      start,
      {
        key: 'open',
        icon: 'i-lucide-circle-pause',
        tone: 'amber',
        title: t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.FLOW.STAYS_OPEN'),
      },
    ];
  }

  const wait = {
    key: 'wait',
    icon: 'i-lucide-timer',
    tone: 'slate',
    title: t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.FLOW.WAIT', {
      duration: duration.value,
    }),
  };

  if (props.mode === 'legacy') {
    return [
      start,
      wait,
      ...goodbyeStep.value,
      {
        key: 'close',
        icon: 'i-lucide-circle-check',
        tone: 'teal',
        title: t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.FLOW.CLOSES'),
      },
    ];
  }

  return [
    start,
    wait,
    {
      key: 'review',
      icon: 'i-lucide-sparkles',
      tone: 'blue',
      title: t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.FLOW.REVIEWS', {
        name: props.name,
      }),
      branches: [
        {
          icon: 'i-lucide-circle-check text-n-teal-11',
          label: t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.FLOW.SOLVED'),
        },
        {
          icon: 'i-lucide-user-round text-n-amber-11',
          label: t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.FLOW.UNSOLVED'),
        },
      ],
    },
    ...goodbyeStep.value,
  ];
});
</script>

<template>
  <FlowSteps
    :title="t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.FLOW.TITLE')"
    :steps="steps"
  />
</template>

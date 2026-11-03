<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import FlowSteps from './FlowSteps.vue';

const props = defineProps({
  name: { type: String, default: '' },
  // Matches config.auto_resolve_mode: evaluated | legacy | disabled
  mode: { type: String, default: 'evaluated' },
  minutes: { type: Number, default: 60 },
  goodbye: { type: String, default: '' },
  sendGoodbye: { type: Boolean, default: false },
  leadsEnabled: { type: Boolean, default: false },
  // A connected website inbox with email continuity off: { id, name }.
  continuityOffInbox: { type: Object, default: null },
});

const { t } = useI18n();
const route = useRoute();

// Mirrors Captain::Behaviour.check_in_after_minutes: half of auto-resolve, rounded down to 5 min, 5 to 30 min.
const CHECK_IN_STEP_MINUTES = 5;
const CHECK_IN_MIN_MINUTES = 5;
const CHECK_IN_MAX_MINUTES = 30;
const CHECK_IN_WITHOUT_AUTO_RESOLVE_MINUTES = 15;

const checkInMinutes = computed(() => {
  if (props.mode === 'disabled') return CHECK_IN_WITHOUT_AUTO_RESOLVE_MINUTES;

  const half =
    Math.floor(props.minutes / 2 / CHECK_IN_STEP_MINUTES) *
    CHECK_IN_STEP_MINUTES;
  return Math.min(Math.max(half, CHECK_IN_MIN_MINUTES), CHECK_IN_MAX_MINUTES);
});

const formatDuration = totalMinutes => {
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
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
};

const duration = computed(() => formatDuration(props.minutes));

const checkInSteps = computed(() => [
  {
    key: 'check-in',
    icon: 'i-lucide-message-circle-question',
    tone: 'blue',
    title: t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.FLOW.CHECK_IN', {
      duration: formatDuration(checkInMinutes.value),
      name: props.name,
    }),
    detail: t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.FLOW.CHECK_IN_DETAIL'),
  },
  ...(props.leadsEnabled
    ? [
        {
          key: 'lead-offer',
          icon: 'i-lucide-mail',
          tone: 'teal',
          title: t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.FLOW.LEAD_OFFER'),
          detail: t(
            'CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.FLOW.LEAD_OFFER_DETAIL'
          ),
        },
      ]
    : []),
]);

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
      ...checkInSteps.value,
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
    title: t(
      'CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.FLOW.WAIT_AFTER_CHECK_IN',
      {
        duration: duration.value,
      }
    ),
  };

  if (props.mode === 'legacy') {
    return [
      start,
      ...checkInSteps.value,
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
    ...checkInSteps.value,
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
  <div class="flex flex-col gap-2">
    <FlowSteps
      :title="t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.FLOW.TITLE')"
      :steps="steps"
    />
    <p
      v-if="continuityOffInbox"
      class="flex items-start gap-1.5 m-0 text-xs text-n-slate-11"
      data-test="continuity-hint"
    >
      <span class="i-lucide-mail-warning mt-0.5 size-3.5 shrink-0" />
      <span>
        {{
          t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.FLOW.CONTINUITY_HINT', {
            inbox: continuityOffInbox.name,
          })
        }}
        <router-link
          :to="{
            name: 'settings_inbox_show',
            params: {
              accountId: route.params.accountId,
              inboxId: continuityOffInbox.id,
            },
          }"
          class="font-medium text-n-blue-11 hover:underline"
        >
          {{ t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.FLOW.CONTINUITY_LINK') }}
        </router-link>
      </span>
    </p>
  </div>
</template>

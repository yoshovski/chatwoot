<script setup>
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys -- Keys share a fixed namespace and come from the lead settings or status list. */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useLeadSettings } from './useLeadSettings';

// The questions as the customer gets them in the website chat, built from the unsaved draft.
// `focus` lights up the messages the open step controls and dims the rest.
const props = defineProps({
  focus: { type: String, default: '' },
});

const { t } = useI18n();
const { label, settings, assistantName, selectedTeamName, hubspotSyncEnabled } =
  useLeadSettings();
const P = (key, params) => label(`PREVIEW.${key}`, params);
const W = (key, params) =>
  t(`CAPTAIN.ASSISTANTS.SETTINGS.LEADS.SETUP.WIDGET.${key}`, params);

const FIELD_ORDER = ['use_case', 'audience_size', 'company', 'country'];
const askedFields = computed(() =>
  settings.value.lead_fields
    .filter(field => field.label && field.key)
    .sort((a, b) => {
      const rank = key =>
        FIELD_ORDER.includes(key)
          ? FIELD_ORDER.indexOf(key)
          : FIELD_ORDER.length;
      return rank(a.key) - rank(b.key);
    })
    .slice(0, settings.value.lead_max_questions)
);

// [{ from: 'visitor' | 'agent', text, step }]
const messages = computed(() => [
  { from: 'visitor', text: P('CHAT.VISITOR_QUESTION'), step: 'when' },
  ...askedFields.value.flatMap(field => [
    {
      from: 'agent',
      text: P('CHAT.BOT_QUALIFY', { field: field.label.toLowerCase() }),
      step: 'ask',
    },
    { from: 'visitor', text: W('ANSWER'), step: 'ask', placeholder: true },
  ]),
  { from: 'agent', text: P('CHAT.BOT_FOLLOW_UP'), step: 'when' },
  { from: 'visitor', text: P('CHAT.VISITOR_CONSENT'), step: 'when' },
  { from: 'agent', text: P('CHAT.BOT_ASK_CONTACT'), step: 'ask' },
  { from: 'visitor', text: P('CONTACT_EXAMPLE'), step: 'ask' },
  { from: 'agent', text: P('CHAT.BOT_SAVED'), step: 'where' },
]);

const destinations = computed(() =>
  [
    { icon: 'i-lucide-inbox', text: W('TO_LIST') },
    selectedTeamName.value && {
      icon: 'i-lucide-mail',
      text: W('TO_TEAM', { team: selectedTeamName.value }),
    },
    hubspotSyncEnabled.value && {
      icon: 'i-lucide-share-2',
      text: W('TO_HUBSPOT'),
    },
  ].filter(Boolean)
);

const dimmed = step => props.focus && props.focus !== step;
</script>

<template>
  <div class="flex flex-col gap-3">
    <div
      class="flex flex-col overflow-hidden rounded-[1.25rem] bg-n-solid-1 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
    >
      <div class="flex items-center gap-2.5 bg-n-brand px-4 py-3 text-white">
        <span
          class="grid size-8 place-items-center rounded-full bg-white/20 text-sm font-semibold"
          aria-hidden="true"
        >
          {{ assistantName.charAt(0) }}
        </span>
        <div class="flex min-w-0 flex-col">
          <span class="truncate text-sm font-semibold">{{
            assistantName
          }}</span>
          <span class="text-xs text-white/80">{{ W('ONLINE') }}</span>
        </div>
      </div>
      <p
        v-if="!settings.leads_enabled"
        class="m-0 bg-n-amber-3 px-4 py-2 text-xs text-n-amber-11"
      >
        {{ W('OFF') }}
      </p>
      <ol
        class="m-0 flex list-none flex-col gap-2 bg-n-background p-3.5 text-[0.8125rem] leading-snug"
        :aria-label="W('LABEL')"
      >
        <li
          v-for="(message, index) in messages"
          :key="index"
          class="max-w-[85%] rounded-2xl px-3 py-2 transition-opacity duration-200"
          :class="[
            message.from === 'visitor'
              ? 'self-end rounded-ee-md bg-n-brand text-white'
              : 'self-start rounded-es-md bg-n-solid-1 text-n-slate-12 shadow-sm',
            { 'italic opacity-90': message.placeholder },
            dimmed(message.step) ? 'opacity-35' : '',
          ]"
        >
          {{ message.text }}
        </li>
      </ol>
      <div class="flex items-center gap-2 border-t border-n-weak px-3.5 py-2.5">
        <span class="flex-1 text-xs text-n-slate-10">{{ W('TYPE_HERE') }}</span>
        <span class="i-lucide-send size-4 text-n-slate-10" aria-hidden="true" />
      </div>
    </div>
    <div
      class="flex flex-col gap-1.5 rounded-2xl bg-n-solid-1 px-3.5 py-3 transition-opacity duration-200"
      :class="dimmed('where') ? 'opacity-50' : ''"
    >
      <span class="text-xs font-semibold text-n-slate-12">{{ W('THEN') }}</span>
      <span
        v-for="item in destinations"
        :key="item.text"
        class="flex items-center gap-2 text-xs text-n-slate-11"
      >
        <span :class="item.icon" class="size-3.5 shrink-0" aria-hidden="true" />
        {{ item.text }}
      </span>
    </div>
  </div>
</template>

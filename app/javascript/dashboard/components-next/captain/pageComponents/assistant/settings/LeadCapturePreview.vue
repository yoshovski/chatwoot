<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  enabled: { type: Boolean, default: false },
  fields: { type: Array, default: () => [] },
  types: { type: Array, default: () => [] },
  maxQuestions: { type: Number, default: 2 },
  handoffCapture: { type: Boolean, default: false },
  teamName: { type: String, default: '' },
});

const { t } = useI18n();
const label = (key, params = {}) =>
  t(`CAPTAIN.ASSISTANTS.SETTINGS.LEADS.PREVIEW.${key}`, params);

const MODES = ['chat', 'handoff', 'viewer'];
const activeMode = ref('chat');

const configuredFields = computed(() =>
  props.fields.filter(item => item.label && item.key)
);
const askedFields = computed(() =>
  configuredFields.value.slice(0, props.maxQuestions)
);
const primaryType = computed(() => props.types[0]?.name || label('NO_TYPE'));
const askedSummary = computed(() =>
  askedFields.value.map(field => field.label.toLowerCase()).join(', ')
);
</script>

<template>
  <div class="flex flex-col gap-4">
    <section
      class="flex flex-col gap-3.5 rounded-2xl bg-n-solid-1 p-4 outline outline-1 outline-n-weak"
    >
      <div class="flex items-center justify-between gap-2">
        <span
          class="text-xs font-semibold uppercase tracking-wider text-n-slate-11"
        >
          {{ label('FLOW') }}
        </span>
        <div
          class="flex rounded-xl bg-n-alpha-1 p-0.5 outline outline-1 outline-n-weak"
          role="radiogroup"
          :aria-label="label('FLOW')"
        >
          <button
            v-for="mode in MODES"
            :key="mode"
            type="button"
            role="radio"
            :aria-checked="activeMode === mode"
            class="rounded-lg px-2.5 py-1 text-xs font-medium transition-colors"
            :class="
              activeMode === mode
                ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
                : 'text-n-slate-11 hover:text-n-slate-12'
            "
            @click="activeMode = mode"
          >
            {{ label(`MODES.${mode.toUpperCase()}`) }}
          </button>
        </div>
      </div>

      <p v-if="!enabled" class="m-0 text-xs text-n-slate-11">
        {{ label('OFF') }}
      </p>

      <div
        class="flex flex-col gap-2.5 rounded-2xl bg-n-alpha-1 p-3.5 text-xs outline outline-1 outline-n-weak"
      >
        <template v-if="activeMode === 'chat'">
          <div
            class="self-end max-w-[85%] rounded-2xl rounded-tr-xs bg-n-brand px-3 py-2 text-white"
          >
            {{ label('CHAT.VISITOR_QUESTION') }}
          </div>
          <div
            class="self-start max-w-[88%] rounded-2xl rounded-tl-xs bg-n-solid-1 px-3 py-2 text-n-slate-12 outline outline-1 outline-n-weak"
          >
            {{
              askedFields.length
                ? label('CHAT.BOT_QUALIFY', { fields: askedSummary })
                : label('CHAT.BOT_ANSWER')
            }}
          </div>
          <div
            v-if="askedFields.length"
            class="self-end max-w-[85%] rounded-2xl rounded-tr-xs bg-n-brand px-3 py-2 text-white"
          >
            {{ label('CHAT.VISITOR_DETAILS') }}
          </div>
          <div
            class="self-start max-w-[88%] rounded-2xl rounded-tl-xs bg-n-solid-1 px-3 py-2 text-n-slate-12 outline outline-1 outline-n-weak"
          >
            {{ label('CHAT.BOT_ASK_CONTACT') }}
          </div>
          <div
            class="self-end max-w-[85%] rounded-2xl rounded-tr-xs bg-n-brand px-3 py-2 text-white"
          >
            {{ label('CONTACT_EXAMPLE') }}
          </div>
        </template>

        <template v-else-if="activeMode === 'handoff'">
          <div
            class="self-end max-w-[85%] rounded-2xl rounded-tr-xs bg-n-brand px-3 py-2 text-white"
          >
            {{ label('HANDOFF_SIM.VISITOR') }}
          </div>
          <div
            class="self-start max-w-[88%] rounded-2xl rounded-tl-xs bg-n-solid-1 px-3 py-2 text-n-slate-12 outline outline-1 outline-n-weak"
          >
            {{ label('HANDOFF_SIM.BOT') }}
          </div>
          <div
            class="flex items-center justify-between gap-2 rounded-xl px-3 py-2 outline outline-1"
            :class="
              handoffCapture
                ? 'bg-n-teal-3/40 text-n-teal-11 outline-n-teal-6'
                : 'bg-n-slate-3 text-n-slate-11 outline-n-weak'
            "
          >
            <span>
              {{
                label(
                  handoffCapture ? 'HANDOFF_SIM.STAGED' : 'HANDOFF_SIM.DISABLED'
                )
              }}
            </span>
            <code v-if="handoffCapture" class="font-mono text-xs">
              {{ primaryType }}
            </code>
          </div>
        </template>

        <template v-else>
          <div
            class="self-end max-w-[85%] rounded-2xl rounded-tr-xs bg-n-brand px-3 py-2 text-white"
          >
            {{ label('VIEWER_SIM.VISITOR') }}
          </div>
          <div
            class="self-start max-w-[88%] rounded-2xl rounded-tl-xs bg-n-solid-1 px-3 py-2 text-n-slate-12 outline outline-1 outline-n-weak"
          >
            {{ label('VIEWER_SIM.BOT') }}
          </div>
          <div
            class="rounded-xl bg-n-slate-3 px-3 py-2 text-n-slate-11 outline outline-1 outline-n-weak"
          >
            {{ label('VIEWER_SIM.NOTE') }}
          </div>
        </template>
      </div>

      <div
        class="flex flex-col gap-2.5 rounded-2xl bg-n-alpha-1 p-3.5 outline outline-1 outline-n-weak"
      >
        <div class="flex items-center justify-between gap-2">
          <span class="text-xs font-semibold text-n-slate-12">
            {{ label('RECORD') }}
          </span>
          <span
            class="rounded-full px-2.5 py-0.5 text-xs font-medium"
            :class="
              activeMode === 'viewer' ||
              (activeMode === 'handoff' && !handoffCapture)
                ? 'bg-n-slate-3 text-n-slate-11'
                : 'bg-n-teal-3 text-n-teal-11'
            "
          >
            {{
              activeMode === 'viewer' ||
              (activeMode === 'handoff' && !handoffCapture)
                ? label('EXCLUDED_BADGE')
                : label('EXAMPLE')
            }}
          </span>
        </div>

        <p
          v-if="
            activeMode === 'viewer' ||
            (activeMode === 'handoff' && !handoffCapture)
          "
          class="m-0 text-xs text-n-slate-11"
        >
          {{ label('NO_LEAD_SAVED') }}
        </p>

        <div v-else class="grid grid-cols-2 gap-1.5 pt-1">
          <div
            class="col-span-2 flex items-center justify-between rounded-xl bg-n-solid-1 px-2.5 py-1.5 outline outline-1 outline-n-weak"
          >
            <span class="text-xs text-n-slate-11">{{
              label('NAME_EMAIL')
            }}</span>
            <span class="truncate text-xs font-medium text-n-slate-12">
              {{ label('CONTACT_EXAMPLE') }}
            </span>
          </div>
          <div
            class="flex flex-col rounded-xl bg-n-solid-1 px-2.5 py-1.5 outline outline-1 outline-n-weak"
          >
            <span class="font-mono text-xs text-n-slate-11">lead_type</span>
            <span class="truncate text-xs font-semibold text-n-slate-12">
              {{ primaryType }}
            </span>
          </div>
          <div
            v-for="field in configuredFields"
            :key="field.key"
            class="flex flex-col rounded-xl bg-n-solid-1 px-2.5 py-1.5 outline outline-1 outline-n-weak"
          >
            <span class="truncate font-mono text-xs text-n-slate-11">
              lead_{{ field.key }}
            </span>
            <span class="truncate text-xs font-medium text-n-slate-12">
              {{ field.label }}
            </span>
          </div>
          <div
            v-if="teamName"
            class="flex flex-col rounded-xl bg-n-solid-1 px-2.5 py-1.5 outline outline-1 outline-n-weak"
          >
            <span class="text-xs text-n-slate-11">{{
              label('TEAM_ALERT')
            }}</span>
            <span class="truncate text-xs font-medium text-n-slate-12">
              {{ teamName }}
            </span>
          </div>
        </div>
      </div>
    </section>
    <p class="m-0 px-1 text-xs leading-relaxed text-n-slate-11">
      {{ label('BOUNDARY') }}
    </p>
  </div>
</template>

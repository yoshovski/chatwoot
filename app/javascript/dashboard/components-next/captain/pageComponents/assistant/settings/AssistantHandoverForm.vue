<script setup>
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { minLength } from '@vuelidate/validators';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useStore, useMapGetter } from 'dashboard/composables/store';

import Editor from 'dashboard/components-next/Editor/Editor.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import SettingsCard from './SettingsCard.vue';
import SettingsSwitchRow from './SettingsSwitchRow.vue';
import SettingsSaveBar from './SettingsSaveBar.vue';
import { useSettingsSave } from './useSettingsSave';
import SettingsSplit from './SettingsSplit.vue';
import HandoffFlow from './HandoffFlow.vue';
import HandoffRules from './HandoffRules.vue';
import ChoiceCard from './ChoiceCard.vue';
import SettingsPanel from './SettingsPanel.vue';
import SummaryRow from './SummaryRow.vue';

const props = defineProps({
  assistant: {
    type: Object,
    default: () => ({}),
  },
  // Async save so the form knows when the request has finished.
  save: {
    type: Function,
    required: true,
  },
});

const { t } = useI18n();
const { isCloudFeatureEnabled } = useAccount();
const { isAdmin } = useAdmin();
const store = useStore();
const agentsList = useMapGetter('agents/getAgents');
const teamsList = useMapGetter('teams/getTeams');

const isCaptainV2Enabled = computed(() =>
  isCloudFeatureEnabled(FEATURE_FLAGS.CAPTAIN_V2)
);
const name = computed(() => props.assistant.name);

onMounted(() => {
  if (isAdmin.value) {
    store.dispatch('agents/get');
    store.dispatch('teams/get');
  }
});

// Mirrors Captain::Conversation::HandoffPolicy::ACTIONS.
const HANDOFF_ACTIONS = ['transfer', 'keep'];

const state = reactive({
  handoffWhenOnline: 'transfer',
  handoffWhenOffline: 'transfer',
  offlineHandoffMessage: '',
  noHandoffMessage: '',
  handoffRules: [],
  handoffMessage: '',
  handoffFormMessage: '',
  handoffCollectName: true,
  handoffCollectPhone: false,
  handoffFallbackAgentId: '',
  handoffFallbackTeamId: '',
  continueWhileWaiting: false,
  handoffSafetyNet: false,
  summaryPrivateNote: true,
  leadPrivateNote: false,
  actionPrivateNote: false,
  resolutionMessage: '',
  instructions: '',
});

const validationRules = {
  handoffMessage: { minLength: minLength(1) },
  resolutionMessage: { minLength: minLength(1) },
  instructions: { minLength: minLength(1) },
};

const v$ = useVuelidate(validationRules, state);

const savedSnapshot = ref('');
const snapshot = () => JSON.stringify(state);
const isDirty = computed(() => snapshot() !== savedSnapshot.value);

const getErrorMessage = field =>
  v$.value[field].$error ? v$.value[field].$errors[0].$message : '';

const formErrors = computed(() => ({
  handoffMessage: getErrorMessage('handoffMessage'),
  resolutionMessage: getErrorMessage('resolutionMessage'),
  instructions: getErrorMessage('instructions'),
}));

const actionOptions = computed(() =>
  HANDOFF_ACTIONS.map(action => ({
    value: action,
    label: t(
      `CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.WHEN.${action.toUpperCase()}`,
      { name: name.value }
    ),
  }))
);
const transfersOffline = computed(
  () => state.handoffWhenOffline === 'transfer'
);
const keepsSometimes = computed(() =>
  [state.handoffWhenOnline, state.handoffWhenOffline].includes('keep')
);

// For teams that never answer in the inbox: the AI agent keeps every conversation and points to email.
const supportEmail = ref('');
const isValidSupportEmail = computed(() =>
  /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(supportEmail.value.trim())
);
const sendToEmail = () => {
  state.handoffWhenOnline = 'keep';
  state.handoffWhenOffline = 'keep';
  state.noHandoffMessage = t(
    'CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.EMAIL_ONLY.MESSAGE',
    { email: supportEmail.value.trim() }
  );
};

const contactFields = computed(() => [
  ...(state.handoffCollectName
    ? [t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.CONTACT_FORM.NAME')]
    : []),
  t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.CONTACT_FORM.EMAIL'),
  ...(state.handoffCollectPhone
    ? [t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.CONTACT_FORM.PHONE')]
    : []),
]);

const noneOption = computed(() => ({
  value: '',
  label: t('CAPTAIN.ASSISTANTS.FORM.FALLBACK_ASSIGNMENTS.NONE'),
}));

const teamOptions = computed(() => [
  noneOption.value,
  ...(teamsList.value || []).map(team => ({
    value: team.id,
    label: team.name,
  })),
]);

const agentOptions = computed(() => [
  noneOption.value,
  ...(agentsList.value || []).map(agent => ({
    value: agent.id,
    label: agent.name || agent.available_name || agent.email,
  })),
]);

const updateStateFromAssistant = assistant => {
  const { config = {} } = assistant;
  state.handoffWhenOnline = config.handoff_when_online || 'transfer';
  state.handoffWhenOffline = config.handoff_when_offline || 'transfer';
  state.offlineHandoffMessage = config.offline_handoff_message || '';
  state.noHandoffMessage = config.no_handoff_message || '';
  state.handoffRules = [...(config.handoff_rules || [])];
  state.handoffMessage = config.handoff_message;
  state.handoffFormMessage = config.handoff_form_message || '';
  state.handoffCollectName = config.handoff_collect_name ?? true;
  state.handoffCollectPhone = config.handoff_collect_phone ?? false;
  state.handoffFallbackAgentId = config.handoff_fallback_agent_id ?? '';
  state.handoffFallbackTeamId = config.handoff_fallback_team_id ?? '';
  state.continueWhileWaiting = config.continue_while_waiting || false;
  state.handoffSafetyNet = config.handoff_safety_net || false;
  // Mirrors Captain::Assistant#summary_private_note? and friends.
  state.summaryPrivateNote = config.summary_private_note !== false;
  state.leadPrivateNote = config.lead_private_note === true;
  state.actionPrivateNote = config.action_private_note === true;
  state.resolutionMessage = config.resolution_message;
  state.instructions = config.instructions;
  savedSnapshot.value = snapshot();
};

const discard = () => {
  v$.value.$reset();
  updateStateFromAssistant(props.assistant);
};

const fallbackTeam = computed(() =>
  (teamsList.value || []).find(
    team => team.id === Number(state.handoffFallbackTeamId)
  )
);
const fallbackAgent = computed(() =>
  (agentsList.value || []).find(
    agent => agent.id === Number(state.handoffFallbackAgentId)
  )
);

// Redesign: the support model is the first decision; details are summaries with side-panel editors.
const U = 'CAPTAIN.AGENT_UX.HANDOFF';
const MODELS = {
  team: ['transfer', 'transfer'],
  teamHours: ['transfer', 'keep'],
  email: ['keep', 'keep'],
};
const supportModel = computed(() => {
  const pair = [state.handoffWhenOnline, state.handoffWhenOffline].join();
  const match = Object.entries(MODELS).find(
    ([, value]) => value.join() === pair
  );
  return match ? match[0] : 'custom';
});
const chooseModel = key => {
  [state.handoffWhenOnline, state.handoffWhenOffline] = MODELS[key];
};
const modelOptions = computed(() => [
  {
    value: 'team',
    icon: 'i-lucide-users',
    label: t(`${U}.MODEL_TEAM`),
    description: t(`${U}.MODEL_TEAM_DESC`, { name: name.value }),
  },
  {
    value: 'teamHours',
    icon: 'i-lucide-clock',
    label: t(`${U}.MODEL_TEAM_HOURS`),
    description: t(`${U}.MODEL_TEAM_HOURS_DESC`, { name: name.value }),
  },
  {
    value: 'email',
    icon: 'i-lucide-mail',
    label: t(`${U}.MODEL_EMAIL`),
    description: t(`${U}.MODEL_EMAIL_DESC`, { name: name.value }),
  },
]);
const actionLabel = action =>
  actionOptions.value.find(option => option.value === action)?.label || action;

const savedConfig = computed(() => props.assistant.config || {});
const savedDestination = computed(() => {
  const config = savedConfig.value;
  if (
    config.handoff_when_online === 'keep' &&
    config.handoff_when_offline === 'keep'
  ) {
    return t('CAPTAIN.AGENT_UX.CONFIGURATION.HANDOFF.KEEPS');
  }
  if (
    !isCaptainV2Enabled.value ||
    (!config.handoff_fallback_agent_id && !config.handoff_fallback_team_id)
  ) {
    return t('CAPTAIN.AGENT_UX.CONFIGURATION.HANDOFF.INBOX');
  }
  if (!isAdmin.value)
    return t('CAPTAIN.AGENT_UX.CONFIGURATION.HANDOFF.CONFIGURED');
  const agent = agentsList.value?.find(
    option => option.id === Number(config.handoff_fallback_agent_id)
  );
  const team = teamsList.value?.find(
    option => option.id === Number(config.handoff_fallback_team_id)
  );
  return (
    [agent?.name, team?.name].filter(Boolean).join(' · ') ||
    t('CAPTAIN.AGENT_UX.CONFIGURATION.HANDOFF.CONFIGURED')
  );
});
const savedRuleCount = computed(
  () => savedConfig.value.handoff_rules?.length || 0
);
const panels = reactive({
  triggers: false,
  messages: false,
  contact: false,
  waiting: false,
  notes: false,
});
const plain = html =>
  (html || '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
const savedMessages = computed(() => {
  const config = savedConfig.value;
  const handoff = plain(config.handoff_message);
  const keep = plain(config.no_handoff_message);
  const defaultMessage = t('CAPTAIN.AGENT_UX.CONFIGURATION.DEFAULT_MESSAGE');
  const online =
    (config.handoff_when_online === 'keep' ? keep : handoff) || defaultMessage;
  const offline =
    (config.handoff_when_offline === 'keep'
      ? keep
      : plain(config.offline_handoff_message) || handoff) || defaultMessage;
  if (online === offline) return online;
  return t('CAPTAIN.AGENT_UX.CONFIGURATION.HANDOFF.MESSAGES', {
    online,
    offline,
  });
});
const triggersSummary = computed(() =>
  state.handoffRules.length
    ? t(
        `${U}.TRIGGERS_SUMMARY`,
        { count: state.handoffRules.length },
        state.handoffRules.length
      )
    : t(`${U}.TRIGGERS_NONE`, { name: name.value })
);
const messagesSummary = computed(
  () =>
    plain(
      supportModel.value === 'email'
        ? state.noHandoffMessage
        : state.handoffMessage
    ) || t('CAPTAIN.AGENT_UX.NOT_SET')
);
const notesSummary = computed(() => {
  const on = [
    state.summaryPrivateNote &&
      t('CAPTAIN.AGENT_UX.HANDOFF.NOTES_HANDOFF_SHORT'),
    state.leadPrivateNote && t('CAPTAIN.AGENT_UX.HANDOFF.NOTES_LEAD_SHORT'),
    state.actionPrivateNote && t('CAPTAIN.AGENT_UX.HANDOFF.NOTES_ACTION_SHORT'),
  ].filter(Boolean);
  return on.length ? on.join(', ') : t('CAPTAIN.AGENT_UX.HANDOFF.NOTES_NONE');
});
const waitingSummary = computed(() =>
  [
    t(
      state.continueWhileWaiting ? `${U}.WAITING_HELPS` : `${U}.WAITING_QUIET`,
      { name: name.value }
    ),
    state.handoffSafetyNet && t(`${U}.SAFETY_ON`),
  ]
    .filter(Boolean)
    .join(' · ')
);
const handsOver = computed(() => supportModel.value !== 'email');
const fieldsToValidate = () => [
  ...(handsOver.value ? ['handoffMessage'] : []),
  ...(isCaptainV2Enabled.value ? [] : ['resolutionMessage', 'instructions']),
];

const handleSubmit = async () => {
  const isValid = await Promise.all(
    fieldsToValidate().map(field => v$.value[field].$validate())
  ).then(results => results.every(Boolean));
  if (!isValid) {
    panels.messages = Boolean(
      formErrors.value.handoffMessage && handsOver.value
    );
    return undefined;
  }

  const payload = {
    config: {
      ...props.assistant.config,
      handoff_message: state.handoffMessage,
      handoff_form_message: state.handoffFormMessage.trim(),
      handoff_collect_name: state.handoffCollectName,
      handoff_collect_phone: state.handoffCollectPhone,
      handoff_when_online: state.handoffWhenOnline,
      handoff_when_offline: state.handoffWhenOffline,
      offline_handoff_message: state.offlineHandoffMessage,
      no_handoff_message: state.noHandoffMessage,
      handoff_rules: state.handoffRules,
      continue_while_waiting: state.continueWhileWaiting,
      handoff_safety_net: state.handoffSafetyNet,
      summary_private_note: state.summaryPrivateNote,
      lead_private_note: state.leadPrivateNote,
      action_private_note: state.actionPrivateNote,
    },
  };

  if (isAdmin.value) {
    payload.config.handoff_fallback_agent_id = state.handoffFallbackAgentId
      ? Number(state.handoffFallbackAgentId)
      : null;
    payload.config.handoff_fallback_team_id = state.handoffFallbackTeamId
      ? Number(state.handoffFallbackTeamId)
      : null;
  }

  if (!isCaptainV2Enabled.value) {
    payload.config.resolution_message = state.resolutionMessage;
    payload.config.instructions = state.instructions;
  }

  return props.save(payload);
};

watch(
  [() => props.assistant.id, () => JSON.stringify(props.assistant.config)],
  discard,
  { immediate: true }
);

const {
  isSaving,
  isSaved,
  saveError,
  save: saveChanges,
} = useSettingsSave(isDirty, handleSubmit);
const handoffFields = ref(null);
const messageEditor = ref(null);
watch(isSaving, async saving => {
  if (saving) return;
  await nextTick();
  const invalidField =
    panels.messages && formErrors.value.handoffMessage
      ? messageEditor.value?.$el
      : handoffFields.value?.querySelector('[aria-invalid="true"]');
  invalidField?.querySelector('[contenteditable="true"]')?.focus();
});
</script>

<template>
  <SettingsSplit>
    <SettingsCard :title="t('CAPTAIN.AGENT_UX.CONFIGURATION.CURRENT')">
      <dl class="m-0 grid gap-2 pt-2 text-sm">
        <div>
          <dt class="font-medium text-n-slate-12">
            {{ t('CAPTAIN.AGENT_UX.CONFIGURATION.HANDOFF.TEAM_AVAILABILITY') }}
          </dt>
          <dd class="m-0 break-words text-n-slate-11">
            {{
              t(`${U}.MODEL_CUSTOM_DESC`, {
                online: actionLabel(
                  savedConfig.handoff_when_online || 'transfer'
                ),
                offline: actionLabel(
                  savedConfig.handoff_when_offline || 'transfer'
                ),
              })
            }}
          </dd>
        </div>
        <div>
          <dt class="font-medium text-n-slate-12">{{ t(`${U}.ASSIGN`) }}</dt>
          <dd class="m-0 break-words text-n-slate-11">
            {{ savedDestination }}
          </dd>
        </div>
        <div>
          <dt class="font-medium text-n-slate-12">{{ t(`${U}.TRIGGERS`) }}</dt>
          <dd class="m-0 break-words text-n-slate-11">
            {{
              t(
                'CAPTAIN.AGENT_UX.CONFIGURATION.HANDOFF.TRIGGERS',
                { count: savedRuleCount },
                savedRuleCount
              )
            }}
          </dd>
        </div>
        <div>
          <dt class="font-medium text-n-slate-12">
            {{ t(`${U}.MESSAGES`, { name }) }}
          </dt>
          <dd class="m-0 break-words text-n-slate-11">{{ savedMessages }}</dd>
        </div>
      </dl>
    </SettingsCard>
    <div ref="handoffFields" class="flex flex-col gap-6" :inert="isSaving">
      <section class="flex flex-col gap-3">
        <h3 class="m-0 text-base font-semibold text-n-slate-12">
          {{ t(`${U}.MODEL_TITLE`, { name }) }}
        </h3>
        <p class="m-0 text-sm text-n-slate-11">
          {{ t('CAPTAIN.AGENT_UX.CONFIGURATION.HANDOFF.SCOPE') }}
        </p>
        <div
          class="flex flex-col gap-2"
          role="radiogroup"
          :aria-label="t(`${U}.MODEL_TITLE`, { name })"
        >
          <ChoiceCard
            v-for="option in modelOptions"
            :key="option.value"
            name="support-model"
            :value="option.value"
            :icon="option.icon"
            :label="option.label"
            :description="option.description"
            :is-active="supportModel === option.value"
            @select="chooseModel(option.value)"
          />
          <ChoiceCard
            v-if="supportModel === 'custom'"
            name="support-model"
            value="custom"
            icon="i-lucide-shuffle"
            :label="t(`${U}.MODEL_CUSTOM`)"
            :description="
              t(`${U}.MODEL_CUSTOM_DESC`, {
                online: actionLabel(state.handoffWhenOnline),
                offline: actionLabel(state.handoffWhenOffline),
              })
            "
            is-active
          />
        </div>
        <div
          v-if="handsOver && isAdmin"
          class="grid gap-3 p-4 rounded-xl bg-n-alpha-1 sm:grid-cols-2"
        >
          <div class="flex flex-col gap-1.5">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t(`${U}.TEAM_LABEL`) }}
            </span>
            <Select
              v-model="state.handoffFallbackTeamId"
              :options="teamOptions"
              :aria-label="t(`${U}.TEAM_LABEL`)"
              class="w-full [&>select]:w-full"
            />
          </div>
          <div class="flex flex-col gap-1.5">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t(`${U}.PERSON_LABEL`) }}
            </span>
            <Select
              v-model="state.handoffFallbackAgentId"
              :options="agentOptions"
              :aria-label="t(`${U}.PERSON_LABEL`)"
              class="w-full [&>select]:w-full"
            />
          </div>
          <p class="m-0 text-xs text-n-slate-11 sm:col-span-2">
            {{ t(`${U}.TEAM_HINT`) }}
          </p>
        </div>
        <form
          v-if="supportModel === 'email'"
          class="flex flex-col gap-2 sm:flex-row sm:items-start"
          @submit.prevent="sendToEmail"
        >
          <Input
            v-model="supportEmail"
            type="email"
            :placeholder="
              t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.EMAIL_ONLY.PLACEHOLDER')
            "
            :aria-label="t(`${U}.EMAIL_LABEL`)"
            class="flex-1"
          />
          <Button
            type="submit"
            :label="t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.EMAIL_ONLY.APPLY')"
            icon="i-lucide-mail"
            variant="faded"
            :disabled="!isValidSupportEmail"
          />
        </form>
      </section>

      <section class="flex flex-col gap-3">
        <h3 class="m-0 text-base font-semibold text-n-slate-12">
          {{ t(`${U}.DETAILS_TITLE`) }}
        </h3>
        <SettingsCard>
          <SummaryRow
            v-if="handsOver"
            icon="i-lucide-git-fork"
            :title="t(`${U}.TRIGGERS`)"
            :summary="triggersSummary"
            @edit="panels.triggers = true"
          />
          <SummaryRow
            icon="i-lucide-message-square-text"
            :title="t(`${U}.MESSAGES`, { name })"
            :summary="messagesSummary"
            @edit="panels.messages = true"
          />
          <SummaryRow
            v-if="handsOver"
            icon="i-lucide-contact-round"
            :title="t(`${U}.CONTACT`)"
            :summary="contactFields.join(', ')"
            @edit="panels.contact = true"
          />
          <SummaryRow
            v-if="handsOver"
            icon="i-lucide-hourglass"
            :title="t(`${U}.WAITING`)"
            :summary="waitingSummary"
            @edit="panels.waiting = true"
          />
          <SummaryRow
            icon="i-lucide-sticky-note"
            :title="t('CAPTAIN.AGENT_UX.HANDOFF.NOTES')"
            :summary="notesSummary"
            @edit="panels.notes = true"
          />
        </SettingsCard>
      </section>

      <template v-if="!isCaptainV2Enabled">
        <Editor
          v-model="state.resolutionMessage"
          :aria-invalid="Boolean(formErrors.resolutionMessage)"
          :label="t('CAPTAIN.ASSISTANTS.FORM.RESOLUTION_MESSAGE.LABEL')"
          :placeholder="
            t('CAPTAIN.ASSISTANTS.FORM.RESOLUTION_MESSAGE.PLACEHOLDER')
          "
          :message="formErrors.resolutionMessage"
          :message-type="formErrors.resolutionMessage ? 'error' : 'info'"
          class="z-0"
        />
        <Editor
          v-model="state.instructions"
          :aria-invalid="Boolean(formErrors.instructions)"
          :label="t('CAPTAIN.ASSISTANTS.FORM.INSTRUCTIONS.LABEL')"
          :placeholder="t('CAPTAIN.ASSISTANTS.FORM.INSTRUCTIONS.PLACEHOLDER')"
          :message="formErrors.instructions"
          :max-length="20000"
          :message-type="formErrors.instructions ? 'error' : 'info'"
          class="z-0"
        />
      </template>
    </div>
    <SettingsSaveBar
      :is-dirty="isDirty"
      :is-saving="isSaving"
      :is-saved="isSaved"
      :error="saveError"
      @save="saveChanges"
      @discard="discard"
    />

    <SettingsPanel
      v-model:open="panels.triggers"
      :title="t(`${U}.TRIGGERS`)"
      :description="t(`${U}.TRIGGERS_PANEL_DESC`, { name })"
    >
      <HandoffRules v-model="state.handoffRules" />
    </SettingsPanel>

    <SettingsPanel
      v-model:open="panels.messages"
      :title="t(`${U}.MESSAGES`, { name })"
      :description="t(`${U}.MESSAGES_PANEL_DESC`)"
      width="xl"
    >
      <Editor
        v-if="handsOver"
        ref="messageEditor"
        v-model="state.handoffMessage"
        :aria-invalid="Boolean(formErrors.handoffMessage)"
        :label="
          t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.MESSAGE_TITLE', { name })
        "
        :placeholder="t('CAPTAIN.ASSISTANTS.FORM.HANDOFF_MESSAGE.PLACEHOLDER')"
        :message="formErrors.handoffMessage"
        :message-type="formErrors.handoffMessage ? 'error' : 'info'"
        class="z-0"
      />
      <Editor
        v-if="transfersOffline"
        v-model="state.offlineHandoffMessage"
        :label="t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.OFFLINE_MESSAGE.LABEL')"
        :placeholder="
          t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.OFFLINE_MESSAGE.PLACEHOLDER')
        "
        :max-length="500"
        class="z-0"
      />
      <Editor
        v-if="keepsSometimes"
        v-model="state.noHandoffMessage"
        :label="
          t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.KEEP_MESSAGE.LABEL', { name })
        "
        :placeholder="
          t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.KEEP_MESSAGE.PLACEHOLDER')
        "
        :max-length="500"
        class="z-0"
      />
    </SettingsPanel>

    <SettingsPanel
      v-model:open="panels.contact"
      :title="t(`${U}.CONTACT`)"
      :description="t(`${U}.CONTACT_PANEL_DESC`)"
      width="xl"
    >
      <label class="flex flex-col gap-2 text-sm text-n-slate-12">
        {{
          t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.CONTACT_FORM.MESSAGE_LABEL')
        }}
        <textarea
          v-model="state.handoffFormMessage"
          :placeholder="
            t(
              'CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.CONTACT_FORM.DEFAULT_MESSAGE'
            )
          "
          maxlength="500"
          rows="3"
          class="w-full p-3 text-sm border rounded-lg border-n-weak bg-n-alpha-1 text-n-slate-12 focus:border-n-brand focus:outline-none"
        />
      </label>
      <div class="flex flex-col divide-y divide-n-weak">
        <SettingsSwitchRow
          v-model="state.handoffCollectName"
          :title="t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.CONTACT_FORM.NAME')"
        />
        <SettingsSwitchRow
          model-value
          disabled
          :title="t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.CONTACT_FORM.EMAIL')"
          :description="
            t(
              'CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.CONTACT_FORM.EMAIL_REQUIRED'
            )
          "
        />
        <SettingsSwitchRow
          v-model="state.handoffCollectPhone"
          :title="t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.CONTACT_FORM.PHONE')"
          :description="
            t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.CONTACT_FORM.PHONE_DESC')
          "
        />
      </div>
      <div class="p-4 text-sm rounded-2xl bg-n-slate-3 text-n-slate-12">
        <p class="mt-0 mb-3 break-words whitespace-pre-wrap">
          {{
            state.handoffFormMessage.trim() ||
            t(
              'CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.CONTACT_FORM.DEFAULT_MESSAGE'
            )
          }}
        </p>
        <Input
          v-for="field in contactFields"
          :key="field"
          :label="field"
          disabled
          class="mb-3"
        />
        <Button
          :label="t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.CONTACT_FORM.SUBMIT')"
          disabled
          class="w-full"
        />
      </div>
    </SettingsPanel>

    <SettingsPanel
      v-model:open="panels.waiting"
      :title="t(`${U}.WAITING`)"
      :description="t(`${U}.WAITING_PANEL_DESC`)"
    >
      <div class="flex flex-col divide-y divide-n-weak">
        <SettingsSwitchRow
          v-model="state.continueWhileWaiting"
          :title="t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.KEEP_HELPING.TITLE')"
          :description="
            t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.KEEP_HELPING.DESC', {
              name,
            })
          "
        />
        <SettingsSwitchRow
          v-if="isAdmin"
          v-model="state.handoffSafetyNet"
          :title="
            t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.SAFETY_NET.TITLE', { name })
          "
          :description="
            t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.SAFETY_NET.DESC', { name })
          "
        />
      </div>
    </SettingsPanel>

    <SettingsPanel
      v-model:open="panels.notes"
      :title="t('CAPTAIN.AGENT_UX.HANDOFF.NOTES')"
      :description="t('CAPTAIN.AGENT_UX.HANDOFF.NOTES_PANEL_DESC', { name })"
    >
      <div class="flex flex-col divide-y divide-n-weak">
        <SettingsSwitchRow
          v-model="state.summaryPrivateNote"
          :title="t('CAPTAIN.AGENT_UX.HANDOFF.NOTES_HANDOFF')"
          :description="t('CAPTAIN.AGENT_UX.HANDOFF.NOTES_HANDOFF_DESC')"
        />
        <SettingsSwitchRow
          v-model="state.leadPrivateNote"
          :title="t('CAPTAIN.AGENT_UX.HANDOFF.NOTES_LEAD')"
        />
        <SettingsSwitchRow
          v-model="state.actionPrivateNote"
          :title="t('CAPTAIN.AGENT_UX.HANDOFF.NOTES_ACTION')"
        />
      </div>
    </SettingsPanel>

    <template #preview>
      <HandoffFlow
        :name="name"
        :message="state.handoffMessage"
        :fallback-team="fallbackTeam?.name"
        :fallback-agent="
          fallbackAgent?.name ||
          fallbackAgent?.available_name ||
          fallbackAgent?.email
        "
        :keep-helping="state.continueWhileWaiting"
        :safety-net="state.handoffSafetyNet"
        :when-online="state.handoffWhenOnline"
        :when-offline="state.handoffWhenOffline"
      />
    </template>
  </SettingsSplit>
</template>

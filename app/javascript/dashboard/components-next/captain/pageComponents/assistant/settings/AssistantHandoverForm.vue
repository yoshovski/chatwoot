<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
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
import SettingsSplit from './SettingsSplit.vue';
import HandoffFlow from './HandoffFlow.vue';
import HandoffRules from './HandoffRules.vue';

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
  handoffFallbackAgentId: '',
  handoffFallbackTeamId: '',
  continueWhileWaiting: false,
  handoffSafetyNet: false,
  resolutionMessage: '',
  instructions: '',
});

const validationRules = {
  handoffMessage: { minLength: minLength(1) },
  resolutionMessage: { minLength: minLength(1) },
  instructions: { minLength: minLength(1) },
};

const v$ = useVuelidate(validationRules, state);

const isSaving = ref(false);
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
  state.handoffFallbackAgentId = config.handoff_fallback_agent_id ?? '';
  state.handoffFallbackTeamId = config.handoff_fallback_team_id ?? '';
  state.continueWhileWaiting = config.continue_while_waiting || false;
  state.handoffSafetyNet = config.handoff_safety_net || false;
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

const fieldsToValidate = () =>
  isCaptainV2Enabled.value
    ? ['handoffMessage']
    : ['handoffMessage', 'resolutionMessage', 'instructions'];

const handleSubmit = async () => {
  const isValid = await Promise.all(
    fieldsToValidate().map(field => v$.value[field].$validate())
  ).then(results => results.every(Boolean));
  if (!isValid) return;

  const payload = {
    config: {
      ...props.assistant.config,
      handoff_message: state.handoffMessage,
      handoff_when_online: state.handoffWhenOnline,
      handoff_when_offline: state.handoffWhenOffline,
      offline_handoff_message: state.offlineHandoffMessage,
      no_handoff_message: state.noHandoffMessage,
      handoff_rules: state.handoffRules,
      continue_while_waiting: state.continueWhileWaiting,
      handoff_safety_net: state.handoffSafetyNet,
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

  isSaving.value = true;
  try {
    await props.save(payload);
  } finally {
    isSaving.value = false;
  }
};

watch(
  () => props.assistant,
  newAssistant => {
    if (newAssistant) updateStateFromAssistant(newAssistant);
  },
  { immediate: true }
);
</script>

<template>
  <SettingsSplit>
    <SettingsCard
      :title="t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.EMAIL_ONLY.TITLE')"
      :description="
        t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.EMAIL_ONLY.DESC', { name })
      "
    >
      <form
        class="flex flex-col gap-2 pt-3 pb-1 sm:flex-row sm:items-start"
        @submit.prevent="sendToEmail"
      >
        <Input
          v-model="supportEmail"
          type="email"
          :placeholder="
            t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.EMAIL_ONLY.PLACEHOLDER')
          "
          :aria-label="
            t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.EMAIL_ONLY.PLACEHOLDER')
          "
          class="flex-1"
        />
        <Button
          type="submit"
          :label="t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.EMAIL_ONLY.APPLY')"
          icon="i-lucide-mail"
          :disabled="!isValidSupportEmail"
        />
      </form>
    </SettingsCard>

    <SettingsCard
      :title="t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.WHEN.TITLE')"
      :description="
        t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.WHEN.DESC', { name })
      "
    >
      <div class="grid gap-3 pt-3 pb-1 sm:grid-cols-2">
        <div class="flex flex-col gap-1.5">
          <span class="text-xs font-medium text-n-slate-11">
            {{ t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.WHEN.ONLINE') }}
          </span>
          <Select
            v-model="state.handoffWhenOnline"
            :options="actionOptions"
            :aria-label="t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.WHEN.ONLINE')"
            class="w-full [&>select]:w-full"
          />
        </div>
        <div class="flex flex-col gap-1.5">
          <span class="text-xs font-medium text-n-slate-11">
            {{ t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.WHEN.OFFLINE') }}
          </span>
          <Select
            v-model="state.handoffWhenOffline"
            :options="actionOptions"
            :aria-label="t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.WHEN.OFFLINE')"
            class="w-full [&>select]:w-full"
          />
        </div>
      </div>
    </SettingsCard>

    <SettingsCard
      :title="t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.MESSAGE_TITLE', { name })"
    >
      <Editor
        v-model="state.handoffMessage"
        :placeholder="t('CAPTAIN.ASSISTANTS.FORM.HANDOFF_MESSAGE.PLACEHOLDER')"
        :message="formErrors.handoffMessage"
        :message-type="formErrors.handoffMessage ? 'error' : 'info'"
        class="z-0 pt-2"
      />
      <Editor
        v-if="transfersOffline"
        v-model="state.offlineHandoffMessage"
        :label="t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.OFFLINE_MESSAGE.LABEL')"
        :placeholder="
          t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.OFFLINE_MESSAGE.PLACEHOLDER')
        "
        :max-length="500"
        class="z-0 pt-4"
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
        class="z-0 pt-4"
      />
    </SettingsCard>

    <SettingsCard
      :title="t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.RULES.TITLE')"
      :description="
        t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.RULES.DESC', { name })
      "
    >
      <HandoffRules v-model="state.handoffRules" />
    </SettingsCard>

    <SettingsCard
      v-if="isAdmin"
      :title="t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.FALLBACK_TITLE')"
      :description="t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.FALLBACK_PREFIX')"
    >
      <div class="grid gap-3 pt-3 pb-1 sm:grid-cols-2">
        <div class="flex flex-col gap-1.5">
          <span class="text-xs font-medium text-n-slate-11">
            {{ t('CAPTAIN.ASSISTANTS.FORM.FALLBACK_ASSIGNMENTS.TEAM_LABEL') }}
          </span>
          <Select
            v-model="state.handoffFallbackTeamId"
            :options="teamOptions"
            :aria-label="
              t('CAPTAIN.ASSISTANTS.FORM.FALLBACK_ASSIGNMENTS.TEAM_LABEL')
            "
            class="w-full [&>select]:w-full"
          />
        </div>
        <div class="flex flex-col gap-1.5">
          <span class="text-xs font-medium text-n-slate-11">
            {{ t('CAPTAIN.ASSISTANTS.FORM.FALLBACK_ASSIGNMENTS.AGENT_LABEL') }}
          </span>
          <Select
            v-model="state.handoffFallbackAgentId"
            :options="agentOptions"
            :aria-label="
              t('CAPTAIN.ASSISTANTS.FORM.FALLBACK_ASSIGNMENTS.AGENT_LABEL')
            "
            class="w-full [&>select]:w-full"
          />
        </div>
      </div>
    </SettingsCard>

    <SettingsCard>
      <SettingsSwitchRow
        v-model="state.continueWhileWaiting"
        :title="t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.KEEP_HELPING.TITLE')"
        :description="
          t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.KEEP_HELPING.DESC', { name })
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
    </SettingsCard>

    <template v-if="!isCaptainV2Enabled">
      <Editor
        v-model="state.resolutionMessage"
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
        :label="t('CAPTAIN.ASSISTANTS.FORM.INSTRUCTIONS.LABEL')"
        :placeholder="t('CAPTAIN.ASSISTANTS.FORM.INSTRUCTIONS.PLACEHOLDER')"
        :message="formErrors.instructions"
        :max-length="20000"
        :message-type="formErrors.instructions ? 'error' : 'info'"
        class="z-0"
      />
    </template>

    <SettingsSaveBar
      :is-dirty="isDirty"
      :is-saving="isSaving"
      @save="handleSubmit"
      @discard="discard"
    />

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

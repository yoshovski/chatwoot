<script setup>
import { computed, onMounted, reactive, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { minLength } from '@vuelidate/validators';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useStore, useMapGetter } from 'dashboard/composables/store';

import Button from 'dashboard/components-next/button/Button.vue';
import Editor from 'dashboard/components-next/Editor/Editor.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import SettingsCard from './SettingsCard.vue';
import SettingsSwitchRow from './SettingsSwitchRow.vue';

const props = defineProps({
  assistant: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['submit']);

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

const state = reactive({
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

const getErrorMessage = field =>
  v$.value[field].$error ? v$.value[field].$errors[0].$message : '';

const formErrors = computed(() => ({
  handoffMessage: getErrorMessage('handoffMessage'),
  resolutionMessage: getErrorMessage('resolutionMessage'),
  instructions: getErrorMessage('instructions'),
}));

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
  state.handoffMessage = config.handoff_message;
  state.handoffFallbackAgentId = config.handoff_fallback_agent_id ?? '';
  state.handoffFallbackTeamId = config.handoff_fallback_team_id ?? '';
  state.continueWhileWaiting = config.continue_while_waiting || false;
  state.handoffSafetyNet = config.handoff_safety_net || false;
  state.resolutionMessage = config.resolution_message;
  state.instructions = config.instructions;
};

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

  emit('submit', payload);
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
  <div class="flex flex-col gap-6">
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
    </SettingsCard>

    <div
      v-if="isAdmin"
      class="flex flex-wrap items-center gap-2 px-5 py-4 text-sm rounded-xl outline outline-1 outline-n-weak bg-n-solid-1 text-n-slate-12"
    >
      <span>{{ t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.FALLBACK_PREFIX') }}</span>
      <Select
        v-model="state.handoffFallbackTeamId"
        :options="teamOptions"
        :aria-label="t('CAPTAIN.ASSISTANTS.FORM.FALLBACK_ASSIGNMENTS.TEAM_LABEL')"
        class="[&>select]:w-full min-w-40"
      />
      <span>{{ t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.FALLBACK_OR') }}</span>
      <Select
        v-model="state.handoffFallbackAgentId"
        :options="agentOptions"
        :aria-label="
          t('CAPTAIN.ASSISTANTS.FORM.FALLBACK_ASSIGNMENTS.AGENT_LABEL')
        "
        class="[&>select]:w-full min-w-40"
      />
    </div>

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

    <div>
      <Button
        :label="t('CAPTAIN.ASSISTANTS.SETTINGS.SAVE')"
        @click="handleSubmit"
      />
    </div>
  </div>
</template>

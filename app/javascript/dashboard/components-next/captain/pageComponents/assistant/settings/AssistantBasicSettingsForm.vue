<script setup>
import { reactive, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Editor from 'dashboard/components-next/Editor/Editor.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useStore, useMapGetter } from 'dashboard/composables/store';

const props = defineProps({
  assistant: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['submit', 'deleteAvatar']);

const { t } = useI18n();
const { isAdmin } = useAdmin();
const store = useStore();
const agentsList = useMapGetter('agents/getAgents');
const teamsList = useMapGetter('teams/getTeams');

onMounted(() => {
  if (isAdmin.value) {
    store.dispatch('agents/get');
    store.dispatch('teams/get');
  }
});

const initialState = {
  name: '',
  description: '',
  productName: '',
  avatar: null,
  avatarUrl: '',
  handoffFallbackAgentId: '',
  handoffFallbackTeamId: '',
  features: {
    conversationFaqs: false,
    memories: false,
    citations: false,
    contactAttributes: false,
    continueWhileWaiting: false,
    handoffSafetyNet: false,
    replyLabels: false,
    outcomeLabels: false,
  },
  replyStyle: {
    suggestedReplies: false,
    maxSuggestedReplies: 3,
    productCards: false,
  },
};

const state = reactive({ ...initialState });

const validationRules = {
  name: { required, minLength: minLength(1) },
  description: { required, minLength: minLength(1) },
  productName: { required, minLength: minLength(1) },
};

const v$ = useVuelidate(validationRules, state);

const getErrorMessage = field => {
  return v$.value[field].$error ? v$.value[field].$errors[0].$message : '';
};

const formErrors = computed(() => ({
  name: getErrorMessage('name'),
  description: getErrorMessage('description'),
  productName: getErrorMessage('productName'),
}));

const updateStateFromAssistant = assistant => {
  const { config = {} } = assistant;
  state.name = assistant.name;
  state.description = assistant.description;
  state.avatarUrl = assistant.avatar_url || '';
  state.avatar = null;
  state.productName = config.product_name;
  state.handoffFallbackAgentId = config.handoff_fallback_agent_id ?? '';
  state.handoffFallbackTeamId = config.handoff_fallback_team_id ?? '';
  state.features = {
    conversationFaqs: config.feature_faq || false,
    memories: config.feature_memory || false,
    citations: config.feature_citation || false,
    contactAttributes: config.feature_contact_attributes || false,
    continueWhileWaiting: config.continue_while_waiting || false,
    handoffSafetyNet: config.handoff_safety_net || false,
    replyLabels: config.reply_labels || false,
    outcomeLabels: config.outcome_labels || false,
  };
  state.replyStyle = {
    suggestedReplies: config.suggested_replies || false,
    maxSuggestedReplies: config.max_suggested_replies ?? 3,
    productCards: config.product_cards || false,
  };
};

const agentOptions = computed(() => {
  const options = [
    {
      value: '',
      label: t('CAPTAIN.ASSISTANTS.FORM.FALLBACK_ASSIGNMENTS.NONE'),
    },
  ];
  (agentsList.value || []).forEach(agent => {
    options.push({
      value: agent.id,
      label: agent.name || agent.available_name || agent.email,
    });
  });
  return options;
});

const teamOptions = computed(() => {
  const options = [
    {
      value: '',
      label: t('CAPTAIN.ASSISTANTS.FORM.FALLBACK_ASSIGNMENTS.NONE'),
    },
  ];
  (teamsList.value || []).forEach(team => {
    options.push({
      value: team.id,
      label: team.name,
    });
  });
  return options;
});

const handleImageUpload = ({ file, url }) => {
  state.avatar = file;
  state.avatarUrl = url;
};

const handleAvatarDelete = () => {
  state.avatar = null;
  state.avatarUrl = '';
  emit('deleteAvatar');
};

const handleBasicInfoUpdate = async () => {
  const result = await Promise.all([
    v$.value.name.$validate(),
    v$.value.description.$validate(),
    v$.value.productName.$validate(),
  ]).then(results => results.every(Boolean));
  if (!result) return;

  const payload = {
    name: state.name,
    description: state.description,
    config: {
      ...props.assistant.config,
      product_name: state.productName,
      feature_faq: state.features.conversationFaqs,
      feature_memory: state.features.memories,
      feature_citation: state.features.citations,
      feature_contact_attributes: state.features.contactAttributes,
      continue_while_waiting: state.features.continueWhileWaiting,
      handoff_safety_net: state.features.handoffSafetyNet,
      reply_labels: state.features.replyLabels,
      outcome_labels: state.features.outcomeLabels,
      suggested_replies: Boolean(state.replyStyle.suggestedReplies),
      max_suggested_replies: Math.min(
        5,
        Math.max(1, Number(state.replyStyle.maxSuggestedReplies) || 3)
      ),
      product_cards: Boolean(state.replyStyle.productCards),
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

  if (state.avatar) {
    payload.avatar = state.avatar;
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
    <div class="mb-2 flex flex-col items-start">
      <span class="mb-2 text-sm font-medium text-n-slate-12">
        {{ t('CAPTAIN.ASSISTANTS.FORM.AVATAR.LABEL') }}
      </span>
      <Avatar
        :src="state.avatarUrl"
        :name="state.name"
        :size="68"
        allow-upload
        icon-name="i-lucide-bot-message-square"
        @upload="handleImageUpload"
        @delete="handleAvatarDelete"
      />
    </div>

    <Input
      v-model="state.name"
      :label="t('CAPTAIN.ASSISTANTS.FORM.NAME.LABEL')"
      :placeholder="t('CAPTAIN.ASSISTANTS.FORM.NAME.PLACEHOLDER')"
      :message="formErrors.name"
      :message-type="formErrors.name ? 'error' : 'info'"
    />

    <Input
      v-model="state.productName"
      :label="t('CAPTAIN.ASSISTANTS.FORM.PRODUCT_NAME.LABEL')"
      :placeholder="t('CAPTAIN.ASSISTANTS.FORM.PRODUCT_NAME.PLACEHOLDER')"
      :message="formErrors.productName"
      :message-type="formErrors.productName ? 'error' : 'info'"
    />

    <Editor
      v-model="state.description"
      :max-length="500"
      :label="t('CAPTAIN.ASSISTANTS.FORM.DESCRIPTION.LABEL')"
      :placeholder="t('CAPTAIN.ASSISTANTS.FORM.DESCRIPTION.PLACEHOLDER')"
      :message="formErrors.description"
      :message-type="formErrors.description ? 'error' : 'info'"
      class="z-0"
    />

    <div class="flex flex-col gap-2">
      <label class="text-sm font-medium text-n-slate-12">
        {{ t('CAPTAIN.ASSISTANTS.FORM.FEATURES.TITLE') }}
      </label>
      <div class="flex flex-col gap-2">
        <label class="flex items-center gap-2">
          <input v-model="state.features.conversationFaqs" type="checkbox" />
          {{ t('CAPTAIN.ASSISTANTS.FORM.FEATURES.ALLOW_CONVERSATION_FAQS') }}
        </label>
        <label class="flex items-center gap-2">
          <input v-model="state.features.memories" type="checkbox" />
          {{ t('CAPTAIN.ASSISTANTS.FORM.FEATURES.ALLOW_MEMORIES') }}
        </label>
        <label class="flex items-center gap-2">
          <input v-model="state.features.citations" type="checkbox" />
          {{ t('CAPTAIN.ASSISTANTS.FORM.FEATURES.ALLOW_CITATIONS') }}
        </label>
        <label class="flex items-center gap-2">
          <input v-model="state.features.contactAttributes" type="checkbox" />
          {{ t('CAPTAIN.ASSISTANTS.FORM.FEATURES.ALLOW_CONTACT_ATTRIBUTES') }}
        </label>
        <label class="flex items-center gap-2">
          <input
            v-model="state.features.continueWhileWaiting"
            type="checkbox"
          />
          {{ t('CAPTAIN.ASSISTANTS.FORM.FEATURES.CONTINUE_WHILE_WAITING') }}
        </label>
        <label v-if="isAdmin" class="flex items-center gap-2">
          <input v-model="state.features.handoffSafetyNet" type="checkbox" />
          {{ t('CAPTAIN.ASSISTANTS.FORM.FEATURES.HANDOFF_SAFETY_NET') }}
        </label>
        <label v-if="isAdmin" class="flex items-center gap-2">
          <input v-model="state.features.replyLabels" type="checkbox" />
          {{ t('CAPTAIN.ASSISTANTS.FORM.FEATURES.REPLY_LABELS') }}
        </label>
        <label v-if="isAdmin" class="flex items-center gap-2">
          <input v-model="state.features.outcomeLabels" type="checkbox" />
          {{ t('CAPTAIN.ASSISTANTS.FORM.FEATURES.OUTCOME_LABELS') }}
        </label>
      </div>
    </div>

    <div class="flex flex-col gap-2">
      <label class="text-sm font-medium text-n-slate-12">
        {{ t('CAPTAIN.ASSISTANTS.FORM.REPLY_STYLE.TITLE') }}
      </label>
      <div class="flex flex-col gap-3">
        <label class="flex items-center gap-2">
          <input v-model="state.replyStyle.suggestedReplies" type="checkbox" />
          {{ t('CAPTAIN.ASSISTANTS.FORM.REPLY_STYLE.SUGGESTED_REPLIES') }}
        </label>
        <Input
          v-if="state.replyStyle.suggestedReplies"
          v-model="state.replyStyle.maxSuggestedReplies"
          type="number"
          min="1"
          max="5"
          :label="t('CAPTAIN.ASSISTANTS.FORM.REPLY_STYLE.MAX_BUTTONS_LABEL')"
          :placeholder="
            t('CAPTAIN.ASSISTANTS.FORM.REPLY_STYLE.MAX_BUTTONS_PLACEHOLDER')
          "
          class="max-w-xs"
        />
        <label class="flex items-center gap-2">
          <input v-model="state.replyStyle.productCards" type="checkbox" />
          {{ t('CAPTAIN.ASSISTANTS.FORM.REPLY_STYLE.PRODUCT_CARDS') }}
        </label>
      </div>
    </div>

    <div v-if="isAdmin" class="flex flex-col gap-3">
      <label class="text-sm font-medium text-n-slate-12">
        {{ t('CAPTAIN.ASSISTANTS.FORM.FALLBACK_ASSIGNMENTS.TITLE') }}
      </label>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-medium text-n-slate-11">
            {{ t('CAPTAIN.ASSISTANTS.FORM.FALLBACK_ASSIGNMENTS.AGENT_LABEL') }}
          </label>
          <Select
            v-model="state.handoffFallbackAgentId"
            :options="agentOptions"
            :placeholder="
              t(
                'CAPTAIN.ASSISTANTS.FORM.FALLBACK_ASSIGNMENTS.AGENT_PLACEHOLDER'
              )
            "
            class="[&>select]:w-full min-w-48"
          />
        </div>
        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-medium text-n-slate-11">
            {{ t('CAPTAIN.ASSISTANTS.FORM.FALLBACK_ASSIGNMENTS.TEAM_LABEL') }}
          </label>
          <Select
            v-model="state.handoffFallbackTeamId"
            :options="teamOptions"
            :placeholder="
              t('CAPTAIN.ASSISTANTS.FORM.FALLBACK_ASSIGNMENTS.TEAM_PLACEHOLDER')
            "
            class="[&>select]:w-full min-w-48"
          />
        </div>
      </div>
    </div>

    <div>
      <Button
        :label="t('CAPTAIN.ASSISTANTS.FORM.UPDATE')"
        @click="handleBasicInfoUpdate"
      />
    </div>
  </div>
</template>

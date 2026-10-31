<script setup>
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import AssistantChatPreview from './AssistantChatPreview.vue';
import ChoiceCard from './ChoiceCard.vue';
import SettingsCard from './SettingsCard.vue';
import SettingsSaveBar from './SettingsSaveBar.vue';
import SettingsSplit from './SettingsSplit.vue';
import SettingsSwitchRow from './SettingsSwitchRow.vue';

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

const ROLE_PROMPT_MAX_LENGTH = 1000;
const WELCOME_MESSAGE_MAX_LENGTH = 300;

const state = reactive({
  agentRole: 'support',
  agentRolePrompt: '',
  visitorAudience: 'customers',
  greetingMode: 'off',
  welcomeMessage: '',
  separateFollowUp: true,
});

const name = computed(() => props.assistant.name);

const roleOptions = computed(() => [
  {
    value: 'adaptive',
    icon: 'i-lucide-sparkles',
    label: t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.ROLE.ADAPTIVE.LABEL'),
    description: t(
      'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.ROLE.ADAPTIVE.DESC'
    ),
  },
  {
    value: 'support',
    icon: 'i-lucide-life-buoy',
    label: t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.ROLE.SUPPORT.LABEL'),
    description: t(
      'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.ROLE.SUPPORT.DESC'
    ),
  },
  {
    value: 'sales',
    icon: 'i-lucide-handshake',
    label: t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.ROLE.SALES.LABEL'),
    description: t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.ROLE.SALES.DESC'),
  },
  {
    value: 'shopping',
    icon: 'i-lucide-shopping-bag',
    label: t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.ROLE.SHOPPING.LABEL'),
    description: t(
      'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.ROLE.SHOPPING.DESC'
    ),
  },
  {
    value: 'custom',
    icon: 'i-lucide-pencil-line',
    label: t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.ROLE.CUSTOM.LABEL'),
    description: t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.ROLE.CUSTOM.DESC'),
  },
]);

const audienceOptions = computed(() => [
  {
    value: 'customers',
    icon: 'i-lucide-user-round-check',
    label: t(
      'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.AUDIENCE.CUSTOMERS.LABEL'
    ),
    description: t(
      'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.AUDIENCE.CUSTOMERS.DESC'
    ),
  },
  {
    value: 'prospects',
    icon: 'i-lucide-telescope',
    label: t(
      'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.AUDIENCE.PROSPECTS.LABEL'
    ),
    description: t(
      'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.AUDIENCE.PROSPECTS.DESC'
    ),
  },
  {
    value: 'detect',
    icon: 'i-lucide-sparkles',
    label: t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.AUDIENCE.DETECT.LABEL'),
    description: t(
      'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.AUDIENCE.DETECT.DESC',
      { name: name.value }
    ),
  },
]);

const greetingOptions = computed(() => [
  {
    value: 'off',
    icon: 'i-lucide-message-circle-off',
    label: t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.GREETING.OFF.LABEL'),
    description: t(
      'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.GREETING.OFF.DESC',
      { name: name.value }
    ),
  },
  {
    value: 'ai',
    icon: 'i-lucide-sparkles',
    label: t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.GREETING.AI.LABEL'),
    description: t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.GREETING.AI.DESC'),
  },
  {
    value: 'fixed',
    icon: 'i-lucide-message-square-quote',
    label: t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.GREETING.FIXED.LABEL'),
    description: t(
      'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.GREETING.FIXED.DESC'
    ),
  },
]);

const isSaving = ref(false);
const showErrors = ref(false);
const savedSnapshot = ref('');
const snapshot = () => JSON.stringify(state);
const isDirty = computed(() => snapshot() !== savedSnapshot.value);

const errors = computed(() => ({
  agentRolePrompt:
    state.agentRole === 'custom' && !state.agentRolePrompt.trim()
      ? t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.ROLE.CUSTOM_REQUIRED')
      : '',
  welcomeMessage:
    state.greetingMode === 'fixed' && !state.welcomeMessage.trim()
      ? t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.GREETING.MESSAGE_REQUIRED')
      : '',
}));

const updateStateFromAssistant = assistant => {
  const { config = {} } = assistant;
  state.agentRole = config.agent_role ?? 'support';
  state.agentRolePrompt = config.agent_role_prompt ?? '';
  state.visitorAudience = config.visitor_audience ?? 'customers';
  state.greetingMode = config.greeting_mode ?? 'off';
  state.welcomeMessage = config.welcome_message ?? '';
  state.separateFollowUp = config.separate_follow_up ?? true;
  showErrors.value = false;
  savedSnapshot.value = snapshot();
};

const discard = () => updateStateFromAssistant(props.assistant);

const handleSubmit = async () => {
  showErrors.value = true;
  if (Object.values(errors.value).some(Boolean)) return;

  isSaving.value = true;
  try {
    await props.save({
      config: {
        ...props.assistant.config,
        agent_role: state.agentRole,
        agent_role_prompt: state.agentRolePrompt.trim(),
        visitor_audience: state.visitorAudience,
        greeting_mode: state.greetingMode,
        welcome_message: state.welcomeMessage.trim(),
        separate_follow_up: state.separateFollowUp,
      },
    });
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

// A static sample exchange that follows the choices; no AI call.
const previewGreeting = computed(() => {
  if (state.greetingMode === 'ai')
    return t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.PREVIEW.GREETING');
  if (state.greetingMode !== 'fixed') return '';
  return state.welcomeMessage
    .trim()
    .replace(
      /\{\{\s*contact\.first_name\s*\}\}/g,
      t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.PREVIEW.FIRST_NAME')
    );
});

// The sample question comes from a prospect or from an existing customer, so a role can be compared on both.
const previewVisitor = ref('prospect');
const isCustomerPreview = computed(() => previewVisitor.value === 'customer');

const previewQuestion = computed(() =>
  isCustomerPreview.value
    ? t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.PREVIEW.CUSTOMER_QUESTION')
    : t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.PREVIEW.QUESTION')
);

const previewAnswer = computed(() => {
  if (isCustomerPreview.value)
    return t(
      'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.PREVIEW.ANSWER_EXISTING_CUSTOMER'
    );
  return state.visitorAudience === 'customers'
    ? t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.PREVIEW.ANSWER_CUSTOMERS')
    : t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.PREVIEW.ANSWER_PROSPECTS');
});

const previewFollowUp = computed(() => {
  const role = state.agentRole;
  if (role === 'sales' || (role === 'adaptive' && !isCustomerPreview.value))
    return t(
      'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.PREVIEW.FOLLOW_UP_SALES'
    );
  if (isCustomerPreview.value)
    return t(
      'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.PREVIEW.FOLLOW_UP_CUSTOMER'
    );
  if (role === 'shopping')
    return t(
      'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.PREVIEW.FOLLOW_UP_SHOPPING'
    );
  return t(
    'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.PREVIEW.FOLLOW_UP_SUPPORT'
  );
});

// The bubbles the agent sends: a fixed welcome is its own bubble, an AI greeting opens the answer.
const previewBubbles = computed(() => {
  const answer =
    state.greetingMode === 'ai'
      ? `${previewGreeting.value} ${previewAnswer.value}`
      : previewAnswer.value;
  const bubbles = state.separateFollowUp
    ? [answer, previewFollowUp.value]
    : [`${answer} ${previewFollowUp.value}`];
  return state.greetingMode === 'fixed' && previewGreeting.value
    ? [previewGreeting.value, ...bubbles]
    : bubbles;
});
</script>

<template>
  <SettingsSplit>
    <SettingsCard
      :title="t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.ROLE.TITLE')"
      :description="
        t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.ROLE.DESC', { name })
      "
    >
      <div class="flex flex-col gap-2 py-3" role="radiogroup">
        <ChoiceCard
          v-for="option in roleOptions"
          :key="option.value"
          name="agent-role"
          :value="option.value"
          :icon="option.icon"
          :label="option.label"
          :description="option.description"
          :is-active="state.agentRole === option.value"
          @select="state.agentRole = option.value"
        />
        <TextArea
          v-if="state.agentRole === 'custom'"
          v-model="state.agentRolePrompt"
          :max-length="ROLE_PROMPT_MAX_LENGTH"
          show-character-count
          :placeholder="
            t(
              'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.ROLE.CUSTOM_PLACEHOLDER'
            )
          "
          :message="showErrors ? errors.agentRolePrompt : ''"
          :message-type="errors.agentRolePrompt ? 'error' : 'info'"
          data-test-id="role-prompt"
        />
      </div>
    </SettingsCard>

    <SettingsCard
      :title="t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.AUDIENCE.TITLE')"
      :description="t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.AUDIENCE.DESC')"
    >
      <div class="flex flex-col gap-2 py-3" role="radiogroup">
        <ChoiceCard
          v-for="option in audienceOptions"
          :key="option.value"
          name="visitor-audience"
          :value="option.value"
          :icon="option.icon"
          :label="option.label"
          :description="option.description"
          :is-active="state.visitorAudience === option.value"
          @select="state.visitorAudience = option.value"
        />
      </div>
    </SettingsCard>

    <SettingsCard
      :title="t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.GREETING.TITLE')"
      :description="t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.GREETING.DESC')"
    >
      <div class="flex flex-col gap-2 py-3" role="radiogroup">
        <ChoiceCard
          v-for="option in greetingOptions"
          :key="option.value"
          name="greeting-mode"
          :value="option.value"
          :icon="option.icon"
          :label="option.label"
          :description="option.description"
          :is-active="state.greetingMode === option.value"
          @select="state.greetingMode = option.value"
        />
        <template v-if="state.greetingMode === 'fixed'">
          <TextArea
            v-model="state.welcomeMessage"
            :max-length="WELCOME_MESSAGE_MAX_LENGTH"
            show-character-count
            :placeholder="
              t(
                'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.GREETING.MESSAGE_PLACEHOLDER'
              )
            "
            :message="showErrors ? errors.welcomeMessage : ''"
            :message-type="errors.welcomeMessage ? 'error' : 'info'"
            data-test-id="welcome-message"
          />
          <p class="m-0 text-xs text-n-slate-11">
            {{
              t(
                'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.GREETING.MESSAGE_HINT'
              )
            }}
          </p>
        </template>
      </div>
    </SettingsCard>

    <SettingsCard
      :title="t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.MESSAGES.TITLE')"
    >
      <SettingsSwitchRow
        v-model="state.separateFollowUp"
        :title="
          t(
            'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.MESSAGES.SEPARATE_FOLLOW_UP.TITLE'
          )
        "
        :description="
          t(
            'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.MESSAGES.SEPARATE_FOLLOW_UP.DESC'
          )
        "
      />
    </SettingsCard>

    <SettingsSaveBar
      :is-dirty="isDirty"
      :is-saving="isSaving"
      @save="handleSubmit"
      @discard="discard"
    />

    <template #preview>
      <div
        class="flex gap-1 p-1 rounded-lg bg-n-alpha-1 w-fit"
        role="group"
        :aria-label="
          t('CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.PREVIEW.VISITOR')
        "
      >
        <Button
          type="button"
          size="xs"
          :variant="isCustomerPreview ? 'ghost' : 'solid'"
          :color="isCustomerPreview ? 'slate' : 'blue'"
          :label="
            t(
              'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.PREVIEW.VISITOR_PROSPECT'
            )
          "
          data-test-id="preview-prospect"
          @click="previewVisitor = 'prospect'"
        />
        <Button
          type="button"
          size="xs"
          :variant="isCustomerPreview ? 'solid' : 'ghost'"
          :color="isCustomerPreview ? 'blue' : 'slate'"
          :label="
            t(
              'CAPTAIN.ASSISTANTS.SETTINGS.CONVERSATION.PREVIEW.VISITOR_CUSTOMER'
            )
          "
          data-test-id="preview-customer"
          @click="previewVisitor = 'customer'"
        />
      </div>
      <AssistantChatPreview :name="name" :avatar-url="assistant.avatar_url">
        <p class="preview-bubble preview-bubble--customer">
          {{ previewQuestion }}
        </p>
        <p
          v-for="(bubble, index) in previewBubbles"
          :key="index"
          class="preview-bubble preview-bubble--agent"
          data-test-id="preview-agent-bubble"
        >
          {{ bubble }}
        </p>
      </AssistantChatPreview>
    </template>
  </SettingsSplit>
</template>

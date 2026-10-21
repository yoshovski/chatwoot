<script setup>
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { maxValue, minLength, minValue, required } from '@vuelidate/validators';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useAccount } from 'dashboard/composables/useAccount';

import Banner from 'dashboard/components-next/banner/Banner.vue';
import Editor from 'dashboard/components-next/Editor/Editor.vue';
import DurationSelect from './DurationSelect.vue';
import SettingsCard from './SettingsCard.vue';
import SettingsSwitchRow from './SettingsSwitchRow.vue';
import SettingsSaveBar from './SettingsSaveBar.vue';
import SettingsSplit from './SettingsSplit.vue';
import ChoiceCard from './ChoiceCard.vue';
import AfterChatFlow from './AfterChatFlow.vue';
import { useAdmin } from 'dashboard/composables/useAdmin';

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

const isCaptainV2Enabled = computed(() =>
  isCloudFeatureEnabled(FEATURE_FLAGS.CAPTAIN_V2)
);

const MIN_INACTIVITY_MINUTES = 5;
const MAX_INACTIVITY_MINUTES = 24 * 60;

const initialState = {
  resolutionMessage: '',
  autoResolveMode: 'evaluated',
  inactivityThresholdMinutes: 60,
  sendInactivityResolutionMessage: true,
  replyLabels: false,
  outcomeLabels: false,
  conversationFaqs: false,
  memories: false,
};

const state = reactive({ ...initialState });

const name = computed(() => props.assistant.name);

const autoResolveOptions = computed(() => [
  {
    value: 'evaluated',
    icon: 'i-lucide-sparkles',
    label: t(
      'CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.MODES.EVALUATED.LABEL',
      { name: name.value }
    ),
    description: t(
      'CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.MODES.EVALUATED.DESCRIPTION',
      { name: name.value }
    ),
  },
  {
    value: 'legacy',
    icon: 'i-lucide-circle-check',
    label: t(
      'CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.MODES.LEGACY.LABEL',
      { name: name.value }
    ),
    description: t(
      'CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.MODES.LEGACY.DESCRIPTION',
      { name: name.value }
    ),
  },
  {
    value: 'disabled',
    icon: 'i-lucide-circle-pause',
    label: t(
      'CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.MODES.DISABLED.LABEL',
      { name: name.value }
    ),
    description: t(
      'CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.MODES.DISABLED.DESCRIPTION',
      { name: name.value }
    ),
  },
]);

const shouldShowInactivityDuration = computed(
  () => state.autoResolveMode !== 'disabled'
);
const initialActionTimingLabel = computed(() =>
  state.autoResolveMode === 'evaluated'
    ? t('CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.REVIEW_AFTER')
    : t('CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.RESOLVE_AFTER')
);

const validationRules = {
  resolutionMessage: { minLength: minLength(1) },
  inactivityThresholdMinutes: {
    required,
    minValue: minValue(MIN_INACTIVITY_MINUTES),
    maxValue: maxValue(MAX_INACTIVITY_MINUTES),
  },
};

const v$ = useVuelidate(validationRules, state);

const isSaving = ref(false);
const savedSnapshot = ref('');
const snapshot = () => JSON.stringify(state);
const isDirty = computed(() => snapshot() !== savedSnapshot.value);

const getErrorMessage = field => {
  return v$.value[field].$error ? v$.value[field].$errors[0].$message : '';
};

const formErrors = computed(() => ({
  resolutionMessage: getErrorMessage('resolutionMessage'),
  inactivityThresholdMinutes: getErrorMessage('inactivityThresholdMinutes'),
}));

const updateStateFromAssistant = assistant => {
  const { config = {} } = assistant;
  state.resolutionMessage = config.resolution_message;
  state.autoResolveMode = config.auto_resolve_mode ?? 'evaluated';
  state.inactivityThresholdMinutes = config.auto_resolve_after ?? 60;
  state.sendInactivityResolutionMessage =
    config.send_inactivity_resolution_message ?? true;
  state.replyLabels = config.reply_labels || false;
  state.outcomeLabels = config.outcome_labels || false;
  state.conversationFaqs = config.feature_faq || false;
  state.memories = config.feature_memory || false;
  savedSnapshot.value = snapshot();
};

const discard = () => {
  v$.value.$reset();
  updateStateFromAssistant(props.assistant);
};

const fieldsToValidate = () => {
  const fields = [];
  if (!isCaptainV2Enabled.value) return fields;

  if (shouldShowInactivityDuration.value) {
    fields.push('inactivityThresholdMinutes');
    if (state.sendInactivityResolutionMessage) fields.push('resolutionMessage');
  }
  return fields;
};

const handleSubmit = async () => {
  const isValid = await Promise.all(
    fieldsToValidate().map(field => v$.value[field].$validate())
  ).then(results => results.every(Boolean));
  if (!isValid) return;

  const payload = {
    config: {
      ...props.assistant.config,
      reply_labels: state.replyLabels,
      outcome_labels: state.outcomeLabels,
      feature_faq: state.conversationFaqs,
      feature_memory: state.memories,
    },
  };

  if (isCaptainV2Enabled.value) {
    Object.assign(payload.config, {
      auto_resolve_mode: state.autoResolveMode,
      auto_resolve_after: state.inactivityThresholdMinutes,
      send_inactivity_resolution_message: state.sendInactivityResolutionMessage,
      resolution_message: state.resolutionMessage,
    });
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
    <section v-if="isCaptainV2Enabled" class="flex flex-col gap-3">
      <h3 class="text-base font-semibold text-n-slate-12">
        {{ t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.QUIET_TITLE') }}
      </h3>
      <div
        class="flex flex-col gap-2"
        role="radiogroup"
        :aria-label="
          t('CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.MODE_LABEL')
        "
      >
        <ChoiceCard
          v-for="option in autoResolveOptions"
          :key="option.value"
          name="auto-resolve-mode"
          :value="option.value"
          :icon="option.icon"
          :label="option.label"
          :description="option.description"
          :is-active="state.autoResolveMode === option.value"
          @select="state.autoResolveMode = option.value"
        />
      </div>

      <Banner v-if="state.autoResolveMode === 'legacy'" color="amber">
        <div class="flex items-start gap-2">
          <span class="i-lucide-triangle-alert mt-0.5 size-4 shrink-0" />
          {{
            t('CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.ALWAYS_WARNING', {
              name,
            })
          }}
        </div>
      </Banner>

      <Banner v-if="state.autoResolveMode === 'disabled'" color="blue">
        <div class="flex items-start gap-2">
          <span class="i-lucide-info mt-0.5 size-4 shrink-0" />
          {{ t('CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.PENDING_INFO') }}
        </div>
      </Banner>

      <SettingsCard v-if="shouldShowInactivityDuration">
        <div
          class="flex flex-col gap-3 py-3.5 lg:flex-row lg:items-center lg:justify-between"
        >
          <span class="text-sm font-medium text-n-slate-12">
            {{ initialActionTimingLabel }}
          </span>
          <DurationSelect
            v-model="state.inactivityThresholdMinutes"
            :error="formErrors.inactivityThresholdMinutes"
            :hours-aria-label="
              t(
                'CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.DURATION_HOURS_ARIA_LABEL'
              )
            "
            :minutes-aria-label="
              t(
                'CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.DURATION_MINUTES_ARIA_LABEL'
              )
            "
          />
        </div>
        <p
          v-if="formErrors.inactivityThresholdMinutes"
          class="pb-3 mb-0 text-xs text-n-ruby-9"
        >
          {{ formErrors.inactivityThresholdMinutes }}
        </p>
        <SettingsSwitchRow
          v-model="state.sendInactivityResolutionMessage"
          :title="
            t(
              'CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.RESOLUTION_MESSAGE.TITLE'
            )
          "
          :description="
            t(
              'CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.RESOLUTION_MESSAGE.DESCRIPTION'
            )
          "
        />
        <div v-if="state.sendInactivityResolutionMessage" class="pt-1 pb-3">
          <Editor
            v-model="state.resolutionMessage"
            :placeholder="
              t('CAPTAIN.ASSISTANTS.FORM.RESOLUTION_MESSAGE.PLACEHOLDER')
            "
            :message="formErrors.resolutionMessage"
            :message-type="formErrors.resolutionMessage ? 'error' : 'info'"
            class="z-0"
          />
        </div>
      </SettingsCard>
    </section>

    <SettingsCard
      v-if="isAdmin"
      :title="t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.ORGANIZE')"
    >
      <SettingsSwitchRow
        v-model="state.replyLabels"
        :title="t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.TOPIC_LABELS.TITLE')"
        :description="
          t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.TOPIC_LABELS.DESC')
        "
      />
      <SettingsSwitchRow
        v-model="state.outcomeLabels"
        :title="
          t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.OUTCOME_LABELS.TITLE')
        "
        :description="
          t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.OUTCOME_LABELS.DESC')
        "
      />
    </SettingsCard>

    <SettingsCard :title="t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.LEARN')">
      <SettingsSwitchRow
        v-model="state.conversationFaqs"
        :title="t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.FAQS.TITLE')"
        :description="t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.FAQS.DESC')"
      />
      <SettingsSwitchRow
        v-model="state.memories"
        :title="t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.MEMORIES.TITLE')"
        :description="
          t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.MEMORIES.DESC', { name })
        "
      />
    </SettingsCard>

    <SettingsSaveBar
      :is-dirty="isDirty"
      :is-saving="isSaving"
      @save="handleSubmit"
      @discard="discard"
    />

    <template v-if="isCaptainV2Enabled" #preview>
      <AfterChatFlow
        :name="name"
        :mode="state.autoResolveMode"
        :minutes="state.inactivityThresholdMinutes"
        :goodbye="
          state.sendInactivityResolutionMessage ? state.resolutionMessage : ''
        "
        :send-goodbye="state.sendInactivityResolutionMessage"
      />
    </template>
  </SettingsSplit>
</template>

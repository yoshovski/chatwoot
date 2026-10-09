<script setup>
import { computed, reactive, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { maxValue, minLength, minValue, required } from '@vuelidate/validators';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useAccount } from 'dashboard/composables/useAccount';

import Banner from 'dashboard/components-next/banner/Banner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Editor from 'dashboard/components-next/Editor/Editor.vue';
import RadioCard from 'dashboard/components-next/radioCard/RadioCard.vue';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import DurationSelect from './DurationSelect.vue';
import SettingsCard from './SettingsCard.vue';
import SettingsSwitchRow from './SettingsSwitchRow.vue';
import { useAdmin } from 'dashboard/composables/useAdmin';

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
    <SettingsToggleSection
      v-if="isCaptainV2Enabled"
      hide-toggle
      :header="t('CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.QUIET_TITLE')"
    >
      <div class="flex w-full flex-col gap-4 pt-3">
        <div
          class="flex flex-col gap-3 px-4"
          role="radiogroup"
          :aria-label="
            t('CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.MODE_LABEL')
          "
        >
          <RadioCard
            v-for="option in autoResolveOptions"
            :id="`auto-resolve-${option.value}`"
            :key="option.value"
            :label="option.label"
            :description="option.description"
            name="auto-resolve-mode"
            :is-active="state.autoResolveMode === option.value"
            @select="state.autoResolveMode = option.value"
          />
        </div>

        <div
          v-if="shouldShowInactivityDuration"
          class="flex flex-col gap-3 border-t border-n-weak pt-4 px-4"
        >
          <div
            class="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between"
          >
            <span class="text-body-main font-medium text-n-slate-12">
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
            class="mb-0 text-xs text-n-ruby-9"
          >
            {{ formErrors.inactivityThresholdMinutes }}
          </p>
        </div>

        <Banner
          v-if="state.autoResolveMode === 'legacy'"
          color="amber"
          class="mx-4"
        >
          <div class="flex items-start gap-2">
            <span class="i-lucide-triangle-alert mt-0.5 size-4 shrink-0" />
            {{
              t(
                'CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.ALWAYS_WARNING',
                {
                  name,
                }
              )
            }}
          </div>
        </Banner>

        <Banner
          v-if="state.autoResolveMode === 'disabled'"
          color="blue"
          class="mx-4"
        >
          <div class="flex items-start gap-2">
            <span class="i-lucide-info mt-0.5 size-4 shrink-0" />
            {{
              t('CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.PENDING_INFO')
            }}
          </div>
        </Banner>

        <div
          v-if="shouldShowInactivityDuration"
          class="flex flex-col gap-2 border-t border-n-weak pt-4 pb-1 px-4"
        >
          <div class="flex items-start justify-between gap-3">
            <div class="flex flex-col gap-1">
              <span class="text-body-main font-medium text-n-slate-12">
                {{
                  t(
                    'CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.RESOLUTION_MESSAGE.TITLE'
                  )
                }}
              </span>
              <span class="text-body-main text-n-slate-11">
                {{
                  t(
                    'CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.RESOLUTION_MESSAGE.DESCRIPTION'
                  )
                }}
              </span>
            </div>
            <Switch
              v-model="state.sendInactivityResolutionMessage"
              :aria-label="
                t(
                  'CAPTAIN.ASSISTANTS.FORM.INACTIVITY_RESOLUTION.RESOLUTION_MESSAGE.TITLE'
                )
              "
            />
          </div>
        </div>
      </div>

      <template
        v-if="
          shouldShowInactivityDuration && state.sendInactivityResolutionMessage
        "
        #editor
      >
        <Editor
          v-model="state.resolutionMessage"
          :placeholder="
            t('CAPTAIN.ASSISTANTS.FORM.RESOLUTION_MESSAGE.PLACEHOLDER')
          "
          :message="formErrors.resolutionMessage"
          :message-type="formErrors.resolutionMessage ? 'error' : 'info'"
          class="z-0 [&_.editor-wrapper]:!min-h-32 [&_.editor-wrapper]:!border-0 [&_.editor-wrapper]:!bg-transparent [&_.editor-wrapper]:!p-0"
        />
      </template>
    </SettingsToggleSection>

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

    <div>
      <Button
        :label="t('CAPTAIN.ASSISTANTS.SETTINGS.SAVE')"
        @click="handleSubmit"
      />
    </div>
  </div>
</template>

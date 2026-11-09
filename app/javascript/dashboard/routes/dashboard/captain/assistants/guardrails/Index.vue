<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAssistantSettings } from '../settings/useAssistantSettings';
import { useBusinessExamples } from 'dashboard/components-next/captain/assistant/useBusinessExamples';

import SettingsPageLayout from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsPageLayout.vue';
import SettingsSplit from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsSplit.vue';
import SettingsCard from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsCard.vue';
import SettingsPanel from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsPanel.vue';
import SummaryRow from 'dashboard/components-next/captain/pageComponents/assistant/settings/SummaryRow.vue';
import RuleList from 'dashboard/components-next/captain/pageComponents/assistant/settings/RuleList.vue';
import AssistantChatPreview from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantChatPreview.vue';
import AssistantOffLimitsMessage from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantOffLimitsMessage.vue';
import AssistantLimits from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantLimits.vue';

// Everything that tells the agent what to do, what to avoid and what it can't do, in one place.
// Was split across Instructions (style rules) and Boundaries.
const { t } = useI18n();
const { assistantId, assistant, updateAssistant } = useAssistantSettings();
const examples = useBusinessExamples(assistantId);
const U = 'CAPTAIN.AGENT_UX.RULES';

const name = computed(() => assistant.value?.name || '');
const guidelines = computed(() => assistant.value?.response_guidelines || []);
const guardrails = computed(() => assistant.value?.guardrails || []);

const saveGuidelines = list => updateAssistant({ response_guidelines: list });
const saveGuardrails = list => updateAssistant({ guardrails: list });

const declineOpen = ref(false);
const offLimitsDraft = ref('');
const declineSummary = computed(
  () => assistant.value?.config?.off_limits_message || t(`${U}.DEFAULT_DECLINE`)
);
</script>

<template>
  <SettingsPageLayout :heading="t('CAPTAIN.AGENT_UX.SECTIONS.BEHAVIOR')">
    <SettingsSplit>
      <RuleList
        :title="t(`${U}.ALWAYS_TITLE`)"
        :description="t(`${U}.ALWAYS_DESC`, { name })"
        :items="guidelines"
        :suggestions="examples.guidelines.value"
        :placeholder="
          t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.ADD.NEW.PLACEHOLDER')
        "
        :add-label="t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.ADD.NEW.TITLE')"
        @update="saveGuidelines"
      />

      <div class="flex flex-col gap-3">
        <RuleList
          :title="t(`${U}.NEVER_TITLE`)"
          :description="t(`${U}.NEVER_DESC`, { name })"
          :items="guardrails"
          :suggestions="examples.guardrails.value"
          :placeholder="t('CAPTAIN.ASSISTANTS.GUARDRAILS.ADD.NEW.PLACEHOLDER')"
          :add-label="t('CAPTAIN.ASSISTANTS.GUARDRAILS.ADD.NEW.TITLE')"
          @update="saveGuardrails"
        />
        <SettingsCard>
          <SummaryRow
            icon="i-lucide-message-square-x"
            :title="t(`${U}.DECLINE_TITLE`, { name })"
            :summary="declineSummary"
            @edit="declineOpen = true"
          />
        </SettingsCard>
      </div>

      <section class="flex flex-col gap-3">
        <div class="flex flex-col gap-0.5">
          <h3 class="m-0 text-base font-semibold text-n-slate-12">
            {{ t(`${U}.CANT_TITLE`) }}
          </h3>
          <p class="m-0 text-sm text-n-slate-11">
            {{ t(`${U}.CANT_DESC`, { name }) }}
          </p>
        </div>
        <AssistantLimits :assistant="assistant" @submit="updateAssistant" />
      </section>

      <template #preview>
        <AssistantChatPreview
          :name="assistant.name"
          :avatar-url="assistant.avatar_url"
        >
          <p class="preview-bubble preview-bubble--customer">
            {{ examples.offLimitsQuestion.value }}
          </p>
          <p class="preview-bubble preview-bubble--agent">
            {{
              offLimitsDraft.trim() ||
              assistant.config?.off_limits_message ||
              t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.OFF_LIMITS.PLACEHOLDER')
            }}
          </p>
        </AssistantChatPreview>
      </template>
    </SettingsSplit>

    <SettingsPanel
      v-model:open="declineOpen"
      :title="t(`${U}.DECLINE_TITLE`, { name })"
      :description="t(`${U}.DECLINE_PANEL_DESC`)"
    >
      <AssistantOffLimitsMessage
        v-model:draft="offLimitsDraft"
        :assistant="assistant"
        @submit="updateAssistant"
      />
    </SettingsPanel>
  </SettingsPageLayout>
</template>

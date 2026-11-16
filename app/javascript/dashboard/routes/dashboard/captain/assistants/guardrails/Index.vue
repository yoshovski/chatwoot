<script setup>
// Translation keys are selected from the fixed mappings in this screen.
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys */
import { computed, nextTick, ref, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import ContactsAPI from 'dashboard/api/contacts';
import { useAssistantSettings } from '../settings/useAssistantSettings';
import { useBusinessExamples } from 'dashboard/components-next/captain/assistant/useBusinessExamples';

import SettingsPageLayout from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsPageLayout.vue';
import { useSettingsSave } from 'dashboard/components-next/captain/pageComponents/assistant/settings/useSettingsSave';
import SettingsSaveBar from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsSaveBar.vue';
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
const fields = ['response_guidelines', 'guardrails'];
const lists = ref({});
const ruleAudiences = ref({});
const offLimitsDraft = ref('');
const limitsForm = ref(null);
const limitsSection = ref(null);
const savedRules = computed(() => ({
  lists: Object.fromEntries(
    fields.map(field => [field, assistant.value[field] || []])
  ),
  audiences: assistant.value.config?.rule_segments || {},
  message: assistant.value.config?.off_limits_message || '',
}));
const declineOpen = ref(false);

const discard = () => {
  const { lists: savedLists, audiences, message } = savedRules.value;
  lists.value = savedLists;
  ruleAudiences.value = audiences;
  offLimitsDraft.value = message;
  limitsForm.value?.reset();
};
watch([assistantId, () => JSON.stringify(savedRules.value)], discard, {
  immediate: true,
});
const isDirty = computed(
  () =>
    Boolean(limitsForm.value?.isDirty) ||
    JSON.stringify(lists.value) !== JSON.stringify(savedRules.value.lists) ||
    JSON.stringify(ruleAudiences.value) !==
      JSON.stringify(savedRules.value.audiences) ||
    offLimitsDraft.value.trim() !== savedRules.value.message
);
const { isSaving, isSaved, saveError, save } = useSettingsSave(
  isDirty,
  async () => {
    if (limitsForm.value.isDirty && !limitsForm.value.validate()) {
      limitsSection.value.open = true;
      return undefined;
    }
    const changes = {};
    fields.forEach(field => {
      if (
        JSON.stringify(lists.value[field]) !==
        JSON.stringify(savedRules.value.lists[field])
      ) {
        changes[field] = lists.value[field];
      }
    });
    const config = { ...assistant.value.config };
    if (
      JSON.stringify(ruleAudiences.value) !==
      JSON.stringify(savedRules.value.audiences)
    ) {
      config.rule_segments = ruleAudiences.value;
    }
    if (offLimitsDraft.value.trim() !== savedRules.value.message) {
      config.off_limits_message = offLimitsDraft.value.trim();
    }
    if (limitsForm.value.isDirty) {
      config.limits = limitsForm.value.limits;
    }
    const ok = await updateAssistant({ ...changes, config });
    if (ok) discard();
    return ok;
  }
);
watch(isSaving, async saving => {
  if (saving || !limitsSection.value?.open) return;
  await nextTick();
  limitsSection.value?.querySelector('input[aria-invalid="true"]')?.focus();
});

const segments = ref([]);
const segmentNames = {
  all: 'CUSTOMERS.SEGMENTS.ALL',
  online: 'CUSTOMERS.SEGMENTS.ONLINE',
  leads: 'CUSTOMERS.SEGMENTS.LEADS',
  new: 'CUSTOMERS.SEGMENTS.NEW',
  waiting: 'CUSTOMERS.SEGMENTS.WAITING',
};
onMounted(async () => {
  try {
    segments.value = (await ContactsAPI.segments()).data.payload.map(
      segment => ({
        ...segment,
        name: segment.built_in ? t(segmentNames[segment.id]) : segment.name,
      })
    );
  } catch {
    /* Existing rules remain editable when the segment list is unavailable. */
  }
});
const editRules = (field, list) => {
  const previous = lists.value[field];
  const audiences = ruleAudiences.value[field] || {};
  const next = Object.fromEntries(
    list
      .map((text, index) => [
        text,
        audiences[text] ||
          (previous.length === list.length ? audiences[previous[index]] : ''),
      ])
      .filter(([, segment]) => segment)
  );
  lists.value = { ...lists.value, [field]: list };
  if (Object.keys(audiences).length || Object.keys(next).length) {
    ruleAudiences.value = { ...ruleAudiences.value, [field]: next };
  }
};
const editAudience = (field, { content, segmentId }) => {
  const next = { ...ruleAudiences.value[field] };
  if (segmentId) next[content] = segmentId;
  else delete next[content];
  const audiences = { ...ruleAudiences.value, [field]: next };
  if (!Object.keys(next).length && !savedRules.value.audiences[field]) {
    delete audiences[field];
  }
  ruleAudiences.value = audiences;
};

const declineSummary = computed(
  () => offLimitsDraft.value.trim() || t(`${U}.DEFAULT_DECLINE`)
);
</script>

<template>
  <SettingsPageLayout :heading="t('CAPTAIN.AGENT_UX.TABS.RULES')">
    <SettingsSplit>
      <SettingsCard
        :title="t('CAPTAIN.AGENT_UX.CONFIGURATION.CURRENT')"
        :description="
          t('CAPTAIN.AGENT_UX.CONFIGURATION.RULES.SUMMARY', {
            always: savedRules.lists.response_guidelines.length,
            never: savedRules.lists.guardrails.length,
          })
        "
      />
      <div class="flex flex-col gap-6" :inert="isSaving">
        <RuleList
          :title="t(`${U}.ALWAYS_TITLE`)"
          :description="t(`${U}.ALWAYS_DESC`, { name })"
          :items="lists.response_guidelines"
          :segments="segments"
          :audiences="ruleAudiences.response_guidelines"
          :suggestions="examples.guidelines.value"
          :placeholder="
            t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.ADD.NEW.PLACEHOLDER')
          "
          :add-label="t('CAPTAIN.AGENT_UX.CONFIGURATION.RULES.ADD_ALWAYS')"
          @audience-change="editAudience('response_guidelines', $event)"
          @update="editRules('response_guidelines', $event)"
        />

        <div class="flex flex-col gap-3">
          <RuleList
            :title="t(`${U}.NEVER_TITLE`)"
            :description="t(`${U}.NEVER_DESC`, { name })"
            :items="lists.guardrails"
            :segments="segments"
            :audiences="ruleAudiences.guardrails"
            :suggestions="examples.guardrails.value"
            :placeholder="
              t('CAPTAIN.AGENT_UX.CONFIGURATION.RULES.NEVER_PLACEHOLDER')
            "
            :add-label="t('CAPTAIN.AGENT_UX.CONFIGURATION.RULES.ADD_NEVER')"
            @audience-change="editAudience('guardrails', $event)"
            @update="editRules('guardrails', $event)"
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

        <details
          ref="limitsSection"
          class="rounded-xl border border-n-weak bg-n-solid-1 p-4"
        >
          <summary class="cursor-pointer text-sm font-semibold text-n-slate-12">
            {{ t(`${U}.CANT_TITLE`) }}
          </summary>
          <p class="mt-2 text-sm text-n-slate-11">
            {{ t(`${U}.CANT_DESC`, { name }) }}
          </p>
          <AssistantLimits ref="limitsForm" :assistant="assistant" />
        </details>
      </div>

      <SettingsSaveBar
        :is-dirty="isDirty"
        :is-saving="isSaving"
        :is-saved="isSaved"
        :error="saveError"
        @save="save"
        @discard="discard"
      />

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
      <AssistantOffLimitsMessage v-model="offLimitsDraft" />
    </SettingsPanel>
  </SettingsPageLayout>
</template>

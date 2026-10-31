<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { picoSearch } from '@chatwoot/pico-search';
import { useStore } from 'dashboard/composables/store';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAssistantSettings } from '../settings/useAssistantSettings';
import { useBusinessExamples } from 'dashboard/components-next/captain/assistant/useBusinessExamples';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';

import SettingsPageLayout from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsPageLayout.vue';
import SettingsCard from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsCard.vue';
import SettingsSplit from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsSplit.vue';
import AssistantChatPreview from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantChatPreview.vue';
import AssistantOffLimitsMessage from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantOffLimitsMessage.vue';
import AssistantLimits from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantLimits.vue';
import SettingsSwitchRow from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsSwitchRow.vue';
import SuggestedRules from 'dashboard/components-next/captain/assistant/SuggestedRules.vue';
import AddNewRulesDialog from 'dashboard/components-next/captain/assistant/AddNewRulesDialog.vue';
import RuleCard from 'dashboard/components-next/captain/assistant/RuleCard.vue';
import BulkSelectBar from 'dashboard/components-next/captain/assistant/BulkSelectBar.vue';

const { t } = useI18n();
const store = useStore();
const { uiSettings, updateUISettings } = useUISettings();
const { assistantId, assistant, updateAssistant } = useAssistantSettings();

const contactAccess = computed({
  get: () => Boolean(assistant.value?.config?.feature_contact_attributes),
  set: value =>
    updateAssistant({
      config: { ...assistant.value.config, feature_contact_attributes: value },
    }),
});

const searchQuery = ref('');
const offLimitsDraft = ref('');
const newDialogRule = ref('');

const guardrailsContent = computed(() => assistant.value?.guardrails || []);

const displayGuardrails = computed(() =>
  guardrailsContent.value.map((c, idx) => ({ id: idx, content: c }))
);

const examples = useBusinessExamples(assistantId);
const guardrailsExample = computed(() =>
  examples.guardrails.value.map((content, id) => ({ id, content }))
);

const filteredGuardrails = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return displayGuardrails.value;
  return picoSearch(displayGuardrails.value, query, ['content']);
});

// Starter examples only help while the list is empty.
const shouldShowSuggestedRules = computed(
  () =>
    !guardrailsContent.value.length &&
    uiSettings.value?.show_guardrails_suggestions !== false
);

const closeSuggestedRules = () => {
  updateUISettings({ show_guardrails_suggestions: false });
};

// Bulk selection & hover state
const bulkSelectedIds = ref(new Set());
const hoveredCard = ref(null);

watch(assistantId, () => {
  bulkSelectedIds.value = new Set();
  hoveredCard.value = null;
});

const handleRuleSelect = id => {
  const selected = new Set(bulkSelectedIds.value);
  selected[selected.has(id) ? 'delete' : 'add'](id);
  bulkSelectedIds.value = selected;
};

const handleRuleHover = (isHovered, id) => {
  hoveredCard.value = isHovered ? id : null;
};

const buildSelectedCountLabel = computed(() => {
  const count = displayGuardrails.value.length || 0;
  const isAllSelected = bulkSelectedIds.value.size === count && count > 0;
  return isAllSelected
    ? t('CAPTAIN.ASSISTANTS.GUARDRAILS.BULK_ACTION.UNSELECT_ALL', { count })
    : t('CAPTAIN.ASSISTANTS.GUARDRAILS.BULK_ACTION.SELECT_ALL', { count });
});

const selectedCountLabel = computed(() => {
  return t('CAPTAIN.ASSISTANTS.GUARDRAILS.BULK_ACTION.SELECTED', {
    count: bulkSelectedIds.value.size,
  });
});

const saveGuardrails = async list => {
  await store.dispatch('captainAssistants/update', {
    id: assistantId.value,
    assistant: { guardrails: list },
  });
};

const addGuardrail = async content => {
  try {
    const newGuardrails = [...guardrailsContent.value, content];
    await saveGuardrails(newGuardrails);
    useAlert(t('CAPTAIN.ASSISTANTS.GUARDRAILS.API.ADD.SUCCESS'));
  } catch (error) {
    useAlert(t('CAPTAIN.ASSISTANTS.GUARDRAILS.API.ADD.ERROR'));
  }
};

const editGuardrail = async ({ id, content }) => {
  try {
    const updated = [...guardrailsContent.value];
    updated[id] = content;
    await saveGuardrails(updated);
    useAlert(t('CAPTAIN.ASSISTANTS.GUARDRAILS.API.UPDATE.SUCCESS'));
  } catch {
    useAlert(t('CAPTAIN.ASSISTANTS.GUARDRAILS.API.UPDATE.ERROR'));
  }
};

const deleteGuardrail = async id => {
  try {
    const updated = guardrailsContent.value.filter((_, idx) => idx !== id);
    await saveGuardrails(updated);
    useAlert(t('CAPTAIN.ASSISTANTS.GUARDRAILS.API.DELETE.SUCCESS'));
  } catch {
    useAlert(t('CAPTAIN.ASSISTANTS.GUARDRAILS.API.DELETE.ERROR'));
  }
};

const bulkDeleteGuardrails = async () => {
  try {
    if (bulkSelectedIds.value.size === 0) return;
    const updated = guardrailsContent.value.filter(
      (_, idx) => !bulkSelectedIds.value.has(idx)
    );
    await saveGuardrails(updated);
    bulkSelectedIds.value.clear();
    useAlert(t('CAPTAIN.ASSISTANTS.GUARDRAILS.API.DELETE.SUCCESS'));
  } catch {
    useAlert(t('CAPTAIN.ASSISTANTS.GUARDRAILS.API.DELETE.ERROR'));
  }
};

const addAllExample = () => {
  updateUISettings({ show_guardrails_suggestions: false });
  try {
    const exampleContents = examples.guardrails.value;
    const newGuardrails = [...guardrailsContent.value, ...exampleContents];
    saveGuardrails(newGuardrails);
  } catch {
    useAlert(t('CAPTAIN.ASSISTANTS.GUARDRAILS.API.ADD.ERROR'));
  }
};
</script>

<template>
  <SettingsPageLayout :heading="t('PLATFORM_NAV.BOUNDARIES')">
    <SettingsSplit>
      <SettingsCard>
        <SettingsSwitchRow
          v-model="contactAccess"
          class="!py-0"
          :title="
            t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.CONTACT_ACCESS.TITLE')
          "
          :description="
            t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.CONTACT_ACCESS.DESC', {
              name: assistant.name,
            })
          "
        />
      </SettingsCard>
      <section class="flex flex-col gap-3">
        <div class="flex items-center justify-between gap-3">
          <h3 class="text-base font-semibold text-n-slate-12">
            {{ t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIST_TITLE') }}
          </h3>
          <div class="flex items-center gap-2">
            <div
              v-if="displayGuardrails.length > 3 && bulkSelectedIds.size === 0"
              class="w-full min-w-0 max-w-60"
            >
              <Input
                v-model="searchQuery"
                size="sm"
                :placeholder="
                  t('CAPTAIN.ASSISTANTS.GUARDRAILS.LIST.SEARCH_PLACEHOLDER')
                "
              />
            </div>
            <BulkSelectBar
              v-model="bulkSelectedIds"
              compact
              :all-items="displayGuardrails"
              :select-all-label="buildSelectedCountLabel"
              :selected-count-label="selectedCountLabel"
              :delete-label="
                t(
                  'CAPTAIN.ASSISTANTS.GUARDRAILS.BULK_ACTION.BULK_DELETE_BUTTON'
                )
              "
              @bulk-delete="bulkDeleteGuardrails"
            >
              <template #default-actions>
                <AddNewRulesDialog
                  v-model="newDialogRule"
                  :placeholder="
                    t('CAPTAIN.ASSISTANTS.GUARDRAILS.ADD.NEW.PLACEHOLDER')
                  "
                  :button-label="
                    t('CAPTAIN.ASSISTANTS.GUARDRAILS.ADD.NEW.TITLE')
                  "
                  :confirm-label="
                    t('CAPTAIN.ASSISTANTS.GUARDRAILS.ADD.NEW.CREATE')
                  "
                  :cancel-label="
                    t('CAPTAIN.ASSISTANTS.GUARDRAILS.ADD.NEW.CANCEL')
                  "
                  @add="addGuardrail"
                />
              </template>
            </BulkSelectBar>
          </div>
        </div>
        <SuggestedRules
          v-if="shouldShowSuggestedRules"
          :title="t('CAPTAIN.ASSISTANTS.GUARDRAILS.ADD.SUGGESTED.TITLE')"
          :items="guardrailsExample"
          @add="addAllExample"
          @close="closeSuggestedRules"
        >
          <template #default="{ item }">
            <div class="flex items-center justify-between w-full">
              <span class="text-sm text-n-slate-12">
                {{ item.content }}
              </span>
              <Button
                :label="
                  t('CAPTAIN.ASSISTANTS.GUARDRAILS.ADD.SUGGESTED.ADD_SINGLE')
                "
                ghost
                xs
                slate
                class="!text-sm !text-n-slate-11 flex-shrink-0"
                @click="addGuardrail(item.content)"
              />
            </div>
          </template>
        </SuggestedRules>
        <p
          v-else-if="displayGuardrails.length === 0"
          class="m-0 text-sm text-n-slate-11"
        >
          {{ t('CAPTAIN.ASSISTANTS.GUARDRAILS.EMPTY_MESSAGE') }}
        </p>
        <p
          v-else-if="filteredGuardrails.length === 0"
          class="m-0 text-sm text-n-slate-11"
        >
          {{ t('CAPTAIN.ASSISTANTS.GUARDRAILS.SEARCH_EMPTY_MESSAGE') }}
        </p>
        <div v-else class="flex flex-col gap-2">
          <RuleCard
            v-for="guardrail in filteredGuardrails"
            :id="guardrail.id"
            :key="guardrail.id"
            :content="guardrail.content"
            :is-selected="bulkSelectedIds.has(guardrail.id)"
            :selectable="
              hoveredCard === guardrail.id || bulkSelectedIds.size > 0
            "
            @select="handleRuleSelect"
            @edit="editGuardrail"
            @delete="deleteGuardrail"
            @hover="isHovered => handleRuleHover(isHovered, guardrail.id)"
          />
        </div>
      </section>
      <AssistantLimits :assistant="assistant" @submit="updateAssistant" />
      <AssistantOffLimitsMessage
        v-model:draft="offLimitsDraft"
        :assistant="assistant"
        @submit="updateAssistant"
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
  </SettingsPageLayout>
</template>

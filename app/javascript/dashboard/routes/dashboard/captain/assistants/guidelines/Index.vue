<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useShopifyIntegration } from 'dashboard/composables/useShopifyIntegration';
import { picoSearch } from '@chatwoot/pico-search';
import { useStore } from 'dashboard/composables/store';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAssistantSettings } from '../settings/useAssistantSettings';
import { useBusinessExamples } from 'dashboard/components-next/captain/assistant/useBusinessExamples';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';

import SettingsPageLayout from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsPageLayout.vue';
import SettingsSplit from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsSplit.vue';
import InstructionsPreview from 'dashboard/components-next/captain/pageComponents/assistant/settings/InstructionsPreview.vue';
import AssistantBehaviorSettings from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantBehaviorSettings.vue';
import SuggestedRules from 'dashboard/components-next/captain/assistant/SuggestedRules.vue';
import AddNewRulesDialog from 'dashboard/components-next/captain/assistant/AddNewRulesDialog.vue';
import RuleCard from 'dashboard/components-next/captain/assistant/RuleCard.vue';
import BulkSelectBar from 'dashboard/components-next/captain/assistant/BulkSelectBar.vue';

const { t } = useI18n();
const store = useStore();
const { isConnected: isShopifyConnected } = useShopifyIntegration();
const { uiSettings, updateUISettings } = useUISettings();
const { assistantId, assistant, updateAssistant } = useAssistantSettings();

const saveBehavior = patch =>
  updateAssistant({ config: { ...assistant.value.config, ...patch } });

const searchQuery = ref('');
const newDialogRule = ref('');

const guidelinesContent = computed(
  () => assistant.value?.response_guidelines || []
);

const displayGuidelines = computed(() =>
  guidelinesContent.value.map((c, idx) => ({ id: idx, content: c }))
);

const examples = useBusinessExamples(assistantId);
const guidelinesExample = computed(() =>
  examples.guidelines.value.map((content, id) => ({ id, content }))
);

const filteredGuidelines = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return displayGuidelines.value;
  return picoSearch(displayGuidelines.value, query, ['content']);
});

// Starter examples only help while the list is empty.
const shouldShowSuggestedRules = computed(
  () =>
    !guidelinesContent.value.length &&
    uiSettings.value?.show_response_guidelines_suggestions !== false
);

const closeSuggestedRules = () => {
  updateUISettings({ show_response_guidelines_suggestions: false });
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
  const count = displayGuidelines.value.length || 0;
  const isAllSelected = bulkSelectedIds.value.size === count && count > 0;
  return isAllSelected
    ? t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.BULK_ACTION.UNSELECT_ALL', {
        count,
      })
    : t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.BULK_ACTION.SELECT_ALL', {
        count,
      });
});

const selectedCountLabel = computed(() => {
  return t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.BULK_ACTION.SELECTED', {
    count: bulkSelectedIds.value.size,
  });
});

const saveGuidelines = async list => {
  await store.dispatch('captainAssistants/update', {
    id: assistantId.value,
    assistant: { response_guidelines: list },
  });
};

const addGuideline = async content => {
  try {
    const updated = [...guidelinesContent.value, content];
    await saveGuidelines(updated);
    useAlert(t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.API.ADD.SUCCESS'));
  } catch {
    useAlert(t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.API.ADD.ERROR'));
  }
};

const editGuideline = async ({ id, content }) => {
  try {
    const updated = [...guidelinesContent.value];
    updated[id] = content;
    await saveGuidelines(updated);
    useAlert(t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.API.UPDATE.SUCCESS'));
  } catch {
    useAlert(t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.API.UPDATE.ERROR'));
  }
};

const deleteGuideline = async id => {
  try {
    const updated = guidelinesContent.value.filter((_, idx) => idx !== id);
    await saveGuidelines(updated);
    useAlert(t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.API.DELETE.SUCCESS'));
  } catch {
    useAlert(t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.API.DELETE.ERROR'));
  }
};

const bulkDeleteGuidelines = async () => {
  try {
    if (bulkSelectedIds.value.size === 0) return;
    const updated = guidelinesContent.value.filter(
      (_, idx) => !bulkSelectedIds.value.has(idx)
    );
    await saveGuidelines(updated);
    bulkSelectedIds.value.clear();
    useAlert(t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.API.DELETE.SUCCESS'));
  } catch {
    useAlert(t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.API.DELETE.ERROR'));
  }
};

const addAllExample = async () => {
  updateUISettings({ show_response_guidelines_suggestions: false });
  try {
    const exampleContents = examples.guidelines.value;
    const newGuidelines = [...guidelinesContent.value, ...exampleContents];
    await saveGuidelines(newGuidelines);
    useAlert(t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.API.ADD.SUCCESS'));
  } catch {
    useAlert(t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.API.ADD.ERROR'));
  }
};
</script>

<template>
  <SettingsPageLayout :heading="t('PLATFORM_NAV.INSTRUCTIONS')">
    <SettingsSplit>
      <AssistantBehaviorSettings
        :assistant="assistant"
        :show-product-cards="isShopifyConnected"
        @update="saveBehavior"
      />
      <section class="flex flex-col gap-3">
        <div class="flex items-center justify-between gap-3">
          <h3 class="text-base font-semibold text-n-slate-12">
            {{ t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.RULES.TITLE') }}
          </h3>
          <div class="flex items-center gap-2">
            <div
              v-if="displayGuidelines.length > 3 && bulkSelectedIds.size === 0"
              class="max-w-60 w-full min-w-0"
            >
              <Input
                v-model="searchQuery"
                size="sm"
                :placeholder="
                  t(
                    'CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.LIST.SEARCH_PLACEHOLDER'
                  )
                "
              />
            </div>
            <BulkSelectBar
              v-model="bulkSelectedIds"
              compact
              :all-items="displayGuidelines"
              :select-all-label="buildSelectedCountLabel"
              :selected-count-label="selectedCountLabel"
              :delete-label="
                t(
                  'CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.BULK_ACTION.BULK_DELETE_BUTTON'
                )
              "
              @bulk-delete="bulkDeleteGuidelines"
            >
              <template #default-actions>
                <AddNewRulesDialog
                  v-model="newDialogRule"
                  :placeholder="
                    t(
                      'CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.ADD.NEW.PLACEHOLDER'
                    )
                  "
                  :button-label="
                    t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.ADD.NEW.TITLE')
                  "
                  :confirm-label="
                    t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.ADD.NEW.CREATE')
                  "
                  :cancel-label="
                    t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.ADD.NEW.CANCEL')
                  "
                  @add="addGuideline"
                />
              </template>
            </BulkSelectBar>
          </div>
        </div>
        <SuggestedRules
          v-if="shouldShowSuggestedRules"
          :title="t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.TITLE')"
          :items="guidelinesExample"
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
                  t(
                    'CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.ADD.SUGGESTED.ADD_SINGLE'
                  )
                "
                ghost
                xs
                slate
                class="!text-sm !text-n-slate-11 flex-shrink-0"
                @click="addGuideline(item.content)"
              />
            </div>
          </template>
        </SuggestedRules>
        <p
          v-else-if="displayGuidelines.length === 0"
          class="m-0 text-sm text-n-slate-11"
        >
          {{ t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.EMPTY_MESSAGE') }}
        </p>
        <p
          v-else-if="filteredGuidelines.length === 0"
          class="m-0 text-sm text-n-slate-11"
        >
          {{ t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.SEARCH_EMPTY_MESSAGE') }}
        </p>
        <div v-else class="flex flex-col gap-2">
          <RuleCard
            v-for="guideline in filteredGuidelines"
            :id="guideline.id"
            :key="guideline.id"
            :content="guideline.content"
            :is-selected="bulkSelectedIds.has(guideline.id)"
            :selectable="
              hoveredCard === guideline.id || bulkSelectedIds.size > 0
            "
            @select="handleRuleSelect"
            @hover="isHovered => handleRuleHover(isHovered, guideline.id)"
            @edit="editGuideline"
            @delete="deleteGuideline"
          />
        </div>
      </section>
      <template #preview>
        <InstructionsPreview
          :assistant="assistant"
          :show-product-cards="isShopifyConnected"
        />
      </template>
    </SettingsSplit>
  </SettingsPageLayout>
</template>

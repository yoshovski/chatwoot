<script setup>
import { computed, ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { picoSearch } from '@chatwoot/pico-search';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';

import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import TestAgentButton from 'dashboard/components-next/captain/TestAgentButton.vue';
import { getToolIdsFromInstruction } from 'dashboard/components-next/captain/scenarios/scenarioTools';
import TemplateGallery from 'dashboard/components-next/captain/scenarios/TemplateGallery.vue';
import ScenariosCard from 'dashboard/components-next/captain/assistant/ScenariosCard.vue';
import BulkSelectBar from 'dashboard/components-next/captain/assistant/BulkSelectBar.vue';
import AddNewScenariosDialog from 'dashboard/components-next/captain/assistant/AddNewScenariosDialog.vue';

const { t } = useI18n();
const route = useRoute();
const store = useStore();
const assistantId = computed(() => Number(route.params.assistantId));

const uiFlags = useMapGetter('captainScenarios/getUIFlags');
const isFetching = computed(() => uiFlags.value.fetchingList);
const scenarios = useMapGetter('captainScenarios/getRecords');
const captainTools = useMapGetter('captainTools/getRecords');
const assistant = computed(() =>
  store.getters['captainAssistants/getRecord'](assistantId.value)
);

const searchQuery = ref('');
const addScenarioDialog = ref(null);

const onUseTemplate = template => {
  addScenarioDialog.value.open({ tab: 'template', template });
};

const onDescribe = () => {
  addScenarioDialog.value.open({ tab: 'describe' });
};

// Bulk selection & hover state
const bulkSelectedIds = ref(new Set());
const hoveredCard = ref(null);
const pendingToggleIds = ref(new Set());

const setTogglePending = (id, isPending) => {
  const pendingIds = new Set(pendingToggleIds.value);
  if (isPending) {
    pendingIds.add(id);
  } else {
    pendingIds.delete(id);
  }
  pendingToggleIds.value = pendingIds;
};

const handleRuleSelect = id => {
  const selected = new Set(bulkSelectedIds.value);
  selected[selected.has(id) ? 'delete' : 'add'](id);
  bulkSelectedIds.value = selected;
};

const buildSelectedCountLabel = computed(() => {
  const count = scenarios.value.length || 0;
  const isAllSelected = bulkSelectedIds.value.size === count && count > 0;
  return isAllSelected
    ? t('CAPTAIN.ASSISTANTS.SCENARIOS.BULK_ACTION.UNSELECT_ALL', { count })
    : t('CAPTAIN.ASSISTANTS.SCENARIOS.BULK_ACTION.SELECT_ALL', { count });
});

const selectedCountLabel = computed(() => {
  return t('CAPTAIN.ASSISTANTS.SCENARIOS.BULK_ACTION.SELECTED', {
    count: bulkSelectedIds.value.size,
  });
});

const handleRuleHover = (isHovered, id) => {
  hoveredCard.value = isHovered ? id : null;
};

const updateScenario = async scenario => {
  try {
    await store.dispatch('captainScenarios/update', {
      id: scenario.id,
      assistantId: assistantId.value,
      ...scenario,
      tools: getToolIdsFromInstruction(scenario.instruction),
    });
    useAlert(t('CAPTAIN.ASSISTANTS.SCENARIOS.API.UPDATE.SUCCESS'));
  } catch (error) {
    const errorMessage =
      error?.response?.message ||
      t('CAPTAIN.ASSISTANTS.SCENARIOS.API.UPDATE.ERROR');
    useAlert(errorMessage);
  }
};

const toggleScenario = async ({ id, enabled }) => {
  if (pendingToggleIds.value.has(id)) return;

  setTogglePending(id, true);
  try {
    await store.dispatch('captainScenarios/update', {
      id,
      assistantId: assistantId.value,
      enabled,
    });
    const successMessage = enabled
      ? t('CAPTAIN.ASSISTANTS.SCENARIOS.API.TOGGLE.ENABLED')
      : t('CAPTAIN.ASSISTANTS.SCENARIOS.API.TOGGLE.DISABLED');
    useAlert(successMessage);
  } catch {
    useAlert(t('CAPTAIN.ASSISTANTS.SCENARIOS.API.TOGGLE.ERROR'));
  } finally {
    setTogglePending(id, false);
  }
};

const deleteScenario = async id => {
  try {
    await store.dispatch('captainScenarios/delete', {
      id,
      assistantId: assistantId.value,
    });
    useAlert(t('CAPTAIN.ASSISTANTS.SCENARIOS.API.DELETE.SUCCESS'));
  } catch (error) {
    const errorMessage =
      error?.response?.message ||
      t('CAPTAIN.ASSISTANTS.SCENARIOS.API.DELETE.ERROR');
    useAlert(errorMessage);
  }
};

// TODO: Add bulk delete endpoint
const bulkDeleteScenarios = async ids => {
  const idsArray = ids || Array.from(bulkSelectedIds.value);
  await Promise.all(
    idsArray.map(id =>
      store.dispatch('captainScenarios/delete', {
        id,
        assistantId: assistantId.value,
      })
    )
  );
  bulkSelectedIds.value = new Set();
  useAlert(t('CAPTAIN.ASSISTANTS.SCENARIOS.API.DELETE.SUCCESS'));
};

const addScenario = async scenario => {
  try {
    await store.dispatch('captainScenarios/create', {
      assistantId: assistantId.value,
      ...scenario,
      tools: getToolIdsFromInstruction(scenario.instruction),
    });
    useAlert(t('CAPTAIN.ASSISTANTS.SCENARIOS.API.ADD.SUCCESS'));
  } catch (error) {
    const errorMessage =
      error?.response?.message ||
      t('CAPTAIN.ASSISTANTS.SCENARIOS.API.ADD.ERROR');
    useAlert(errorMessage);
  }
};

const STATUS_FILTERS = ['all', 'active', 'paused'];
const statusFilter = ref('all');

const statusCounts = computed(() => ({
  all: scenarios.value.length,
  active: scenarios.value.filter(scenario => scenario.enabled).length,
  paused: scenarios.value.filter(scenario => !scenario.enabled).length,
}));

const filteredScenarios = computed(() => {
  const query = searchQuery.value.trim();
  const source = scenarios.value.filter(scenario => {
    if (statusFilter.value === 'active') return scenario.enabled;
    if (statusFilter.value === 'paused') return !scenario.enabled;
    return true;
  });
  if (!query) return source;
  return picoSearch(source, query, ['title', 'description', 'instruction']);
});

onMounted(() => {
  store.dispatch('captainScenarios/get', {
    assistantId: assistantId.value,
  });
  store.dispatch('captainTools/getTools');
  store.dispatch('captainAssistants/show', { id: assistantId.value });
});
</script>

<template>
  <PageLayout
    :header-title="$t('CAPTAIN.ASSISTANTS.SCENARIOS.TITLE')"
    :is-fetching="isFetching"
    :show-know-more="false"
    :show-pagination-footer="false"
    :button-label="$t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.NEW.TITLE')"
    @click="() => addScenarioDialog.open()"
  >
    <template #headerActions>
      <TestAgentButton :assistant-id="assistantId" />
    </template>
    <template #body>
      <div class="flex w-full flex-col gap-6 pb-8">
        <!-- If scenarios exist, lead with the scenario list -->
        <div v-if="scenarios.length > 0" class="flex flex-col gap-4">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <div
              v-if="bulkSelectedIds.size === 0"
              class="flex items-center gap-1 p-0.5 rounded-lg bg-n-alpha-1"
              role="group"
              :aria-label="t('CAPTAIN.ASSISTANTS.SCENARIOS.FILTER.LABEL')"
            >
              <button
                v-for="filter in STATUS_FILTERS"
                :key="filter"
                type="button"
                class="px-3 py-1 text-sm rounded-md transition-colors"
                :class="
                  statusFilter === filter
                    ? 'bg-n-solid-1 text-n-slate-12 font-medium shadow-sm'
                    : 'text-n-slate-11 hover:text-n-slate-12'
                "
                :aria-pressed="statusFilter === filter"
                @click="statusFilter = filter"
              >
                {{
                  t(
                    `CAPTAIN.ASSISTANTS.SCENARIOS.FILTER.${filter.toUpperCase()}`,
                    { count: statusCounts[filter] }
                  )
                }}
              </button>
            </div>
            <BulkSelectBar
              v-model="bulkSelectedIds"
              compact
              :all-items="scenarios"
              :select-all-label="buildSelectedCountLabel"
              :selected-count-label="selectedCountLabel"
              :delete-label="
                $t(
                  'CAPTAIN.ASSISTANTS.SCENARIOS.BULK_ACTION.BULK_DELETE_BUTTON'
                )
              "
              @bulk-delete="bulkDeleteScenarios"
            />
            <div
              v-if="bulkSelectedIds.size === 0"
              class="w-full min-w-0 ms-auto max-w-64"
            >
              <Input
                v-model="searchQuery"
                size="sm"
                type="search"
                :placeholder="
                  t('CAPTAIN.ASSISTANTS.SCENARIOS.LIST.SEARCH_PLACEHOLDER')
                "
              />
            </div>
          </div>

          <div v-if="filteredScenarios.length === 0" class="mt-1 mb-2">
            <span class="text-n-slate-11 text-sm">
              {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.SEARCH_EMPTY_MESSAGE') }}
            </span>
          </div>
          <div v-else class="flex flex-col gap-2">
            <ScenariosCard
              v-for="scenario in filteredScenarios"
              :id="scenario.id"
              :key="scenario.id"
              :title="scenario.title"
              :description="scenario.description"
              :instruction="scenario.instruction"
              :tools="scenario.tools"
              :enabled="scenario.enabled"
              :is-updating="pendingToggleIds.has(scenario.id)"
              :is-selected="bulkSelectedIds.has(scenario.id)"
              :selectable="
                hoveredCard === scenario.id || bulkSelectedIds.size > 0
              "
              @select="handleRuleSelect"
              @delete="deleteScenario(scenario.id)"
              @update="updateScenario"
              @toggle="toggleScenario"
              @hover="isHovered => handleRuleHover(isHovered, scenario.id)"
            />
          </div>

          <div class="pt-6 mt-2 border-t border-n-weak">
            <TemplateGallery
              :tools="captainTools"
              has-scenarios
              @use-template="onUseTemplate"
              @describe="onDescribe"
            />
          </div>
        </div>

        <!-- Empty state: Lead with templates and creation action -->
        <div v-else-if="!isFetching" class="flex flex-col gap-6">
          <div
            class="flex flex-col items-center gap-3 px-6 py-10 text-center rounded-xl border border-dashed border-n-strong"
          >
            <span
              class="flex items-center justify-center rounded-xl size-10 bg-n-brand/10 text-n-blue-11"
            >
              <span class="i-lucide-route size-5" />
            </span>
            <div class="flex flex-col gap-1 max-w-md">
              <h3 class="m-0 text-base font-medium text-n-slate-12">
                {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.EMPTY_TITLE') }}
              </h3>
              <p class="m-0 text-sm text-n-slate-11">
                {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.EMPTY_MESSAGE') }}
              </p>
            </div>
            <Button
              sm
              icon="i-lucide-sparkles"
              :label="
                t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.DESCRIBE.TITLE')
              "
              @click="onDescribe"
            />
          </div>
          <TemplateGallery
            :tools="captainTools"
            :has-scenarios="false"
            @use-template="onUseTemplate"
            @describe="onDescribe"
          />
        </div>

        <AddNewScenariosDialog
          ref="addScenarioDialog"
          :assistant-id="assistantId"
          :assistant="assistant"
          :tools="captainTools"
          :show-trigger="false"
          @add="addScenario"
        />
      </div>
    </template>
  </PageLayout>
</template>

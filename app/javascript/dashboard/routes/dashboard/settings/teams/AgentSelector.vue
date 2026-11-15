<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'next/avatar/Avatar.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import DataTable from 'dashboard/components-next/kit/DataTable.vue';

// The teammates of the account with a checkbox each; the page's form saves the selection.
const props = defineProps({
  agentList: {
    type: Array,
    default: () => [],
  },
  selectedAgents: {
    type: Array,
    default: () => [],
  },
  updateSelectedAgents: {
    type: Function,
    default: () => {},
  },
});

const { t } = useI18n();

const allAgentsSelected = computed(
  () =>
    props.selectedAgents.length === props.agentList.length &&
    props.agentList.length > 0
);

const someAgentsSelected = computed(
  () => props.selectedAgents.length > 0 && !allAgentsSelected.value
);

const isAgentSelected = agentId => props.selectedAgents.includes(agentId);

const handleSelectAgent = agentId => {
  const result = isAgentSelected(agentId)
    ? props.selectedAgents.filter(item => item !== agentId)
    : [...props.selectedAgents, agentId];
  props.updateSelectedAgents(result);
};

const toggleSelectAll = () => {
  props.updateSelectedAgents(
    allAgentsSelected.value ? [] : props.agentList.map(item => item.id)
  );
};

const columns = computed(() => [
  {
    key: 'select',
    label: t('TEAMS_SETTINGS.WIZARD.SELECT_ALL'),
    class: 'w-10',
  },
  { key: 'name', label: t('TEAMS_SETTINGS.AGENTS.AGENT') },
  { key: 'email', label: t('TEAMS_SETTINGS.AGENTS.EMAIL') },
]);
</script>

<template>
  <DataTable :columns="columns" :rows="agentList">
    <template #head-select>
      <Checkbox
        :model-value="allAgentsSelected"
        :indeterminate="someAgentsSelected"
        :aria-label="t('TEAMS_SETTINGS.WIZARD.SELECT_ALL')"
        @change="toggleSelectAll"
      />
    </template>
    <template #cell-select="{ row: agent }">
      <Checkbox
        :model-value="isAgentSelected(agent.id)"
        :aria-label="agent.name"
        @change="() => handleSelectAgent(agent.id)"
      />
    </template>
    <template #cell-name="{ row: agent }">
      <div class="flex min-w-0 items-center gap-2">
        <Avatar
          :src="agent.thumbnail"
          :name="agent.name"
          :status="agent.availability_status"
          :size="24"
          hide-offline-status
          rounded-full
          class="shrink-0"
        />
        <span class="truncate font-medium text-n-slate-12">
          {{ agent.name }}
        </span>
      </div>
    </template>
    <template #cell-email="{ row: agent }">
      <span class="block truncate text-n-slate-11">
        {{ agent.email || '---' }}
      </span>
    </template>
  </DataTable>
</template>

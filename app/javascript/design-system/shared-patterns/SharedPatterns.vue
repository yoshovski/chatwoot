<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import FormLayout from 'dashboard/components-next/kit/FormLayout.vue';
import MetricTile from 'dashboard/components-next/kit/MetricTile.vue';
import PageFrame from 'dashboard/components-next/kit/PageFrame.vue';
import PageHeader from 'dashboard/components-next/kit/PageHeader.vue';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';
import TableCard from 'dashboard/components-next/kit/TableCard.vue';

defineProps({ layout: { type: String, required: true } });

const { t } = useI18n();
const collectionStates = [
  { value: 'ready', label: t('FIXTURE.STATES.ready') },
  { value: 'loading', label: t('FIXTURE.STATES.loading') },
  { value: 'empty', label: t('FIXTURE.STATES.empty') },
  { value: 'error', label: t('FIXTURE.STATES.error') },
  { value: 'unavailable', label: t('FIXTURE.STATES.unavailable') },
];

const columns = [
  { key: 'name', label: 'Source' },
  { key: 'status', label: 'Status' },
];
const sampleRows = [
  {
    id: 1,
    name: 'International shipping and delivery times for oversized orders',
    status: 'Ready',
  },
  { id: 2, name: 'Returns and exchanges', status: 'Processing' },
];
const collection = ref('ready');
const workspace = ref('Northwind Outdoor Supply');
const savedWorkspace = ref(workspace.value);
const dirty = computed(() => workspace.value !== savedWorkspace.value);
const saving = ref(false);
const saved = ref(false);
const error = ref('');

const save = async () => {
  saving.value = true;
  saved.value = false;
  error.value = '';
  const name = workspace.value.trim();
  await new Promise(resolve => {
    setTimeout(resolve, 350);
  });
  if (name) {
    savedWorkspace.value = name;
    workspace.value = name;
    saved.value = true;
  } else {
    error.value = 'Enter a workspace name.';
  }
  saving.value = false;
};

const discard = () => {
  workspace.value = savedWorkspace.value;
  saved.value = false;
  error.value = '';
};
</script>

<template>
  <PageFrame v-if="layout === 'collection'" size="wide" class="min-h-96">
    <template #header>
      <PageHeader :title="$t('FIXTURE.SOURCES')">
        <template #action>
          <Button
            label="Add sample source"
            size="sm"
            @click="collection = 'ready'"
          />
        </template>
      </PageHeader>
    </template>
    <label class="text-sm text-n-slate-12">
      {{ $t('FIXTURE.PREVIEW_STATE') }}
      <select v-model="collection" class="!mb-0 max-w-xs">
        <option
          v-for="state in collectionStates"
          :key="state.value"
          :value="state.value"
        >
          {{ state.label }}
        </option>
      </select>
    </label>
    <TableCard
      :columns="columns"
      :rows="collection === 'ready' ? sampleRows : []"
      :search-keys="['name']"
      :loading="collection === 'loading'"
      :error="collection === 'error'"
      :unavailable-text="
        collection === 'unavailable'
          ? 'Only workspace administrators can view sources.'
          : ''
      "
      loading-text="Loading sources…"
      error-text="Could not load sources"
      retry-label="Retry"
      empty-title="Add your first knowledge source"
      empty-description="Give your AI agent product and policy information."
      search-placeholder="Search sources"
      no-results-text="No sources match your search"
      @retry="collection = 'ready'"
    >
      <template #empty>
        <Button
          label="Add sample source"
          size="sm"
          @click="collection = 'ready'"
        />
      </template>
    </TableCard>
  </PageFrame>
  <PageFrame v-else-if="layout === 'configuration'" class="min-h-96">
    <template #header>
      <PageHeader :title="$t('FIXTURE.BUSINESS_DETAILS')" />
    </template>
    <FormLayout
      save-label="Save changes"
      saved-label="Changes saved"
      :dirty="dirty"
      :saving="saving"
      :saved="saved"
      :error="error"
      @save="save"
      @discard="discard"
    >
      <SectionCard :title="$t('FIXTURE.WORKSPACE_IDENTITY')">
        <label class="text-sm text-n-slate-12">
          {{ $t('FIXTURE.WORKSPACE_NAME') }}
          <input
            v-model="workspace"
            type="text"
            class="!mb-0"
            :readonly="saving"
            :aria-invalid="!!error"
            :aria-describedby="error ? 'fixture-workspace-error' : undefined"
            @input="error = ''"
          />
        </label>
        <span v-if="error" id="fixture-workspace-error" class="sr-only">
          {{ error }}
        </span>
      </SectionCard>
    </FormLayout>
  </PageFrame>
  <PageFrame v-else class="min-h-96">
    <template #header>
      <PageHeader
        :title="$t('FIXTURE.SUPPORT_OVERVIEW')"
        description="Northwind Outdoor Supply · Last 7 days"
      />
    </template>
    <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
      <MetricTile
        label="Conversations handled by your AI agent"
        :value="186"
        icon="i-lucide-bot"
        hint="Conversations with at least one AI reply across this workspace over the last 7 days."
      />
      <MetricTile
        label="Median first response time"
        value="—"
        icon="i-lucide-clock"
        tone="teal"
        hint="Unavailable because the response-time report could not be loaded for the last 7 days."
      />
    </div>
  </PageFrame>
</template>

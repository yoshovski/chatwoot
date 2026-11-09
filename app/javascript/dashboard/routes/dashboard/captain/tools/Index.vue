<script setup>
import { computed, onMounted, ref, nextTick, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { usePolicy } from 'dashboard/composables/usePolicy';

import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import CaptainPaywall from 'dashboard/components-next/captain/pageComponents/Paywall.vue';
import BuiltInActionsSection from 'dashboard/components-next/captain/pageComponents/builtInActions/BuiltInActionsSection.vue';
import EmailTemplatesSection from 'dashboard/components-next/captain/pageComponents/builtInActions/EmailTemplatesSection.vue';
import CustomToolCard from 'dashboard/components-next/captain/pageComponents/customTool/CustomToolCard.vue';
import DeleteDialog from 'dashboard/components-next/captain/pageComponents/DeleteDialog.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import McpServerCard from 'dashboard/components-next/captain/pageComponents/mcpServer/McpServerCard.vue';
import ConnectMcpServerDialog from 'dashboard/components-next/captain/pageComponents/mcpServer/ConnectMcpServerDialog.vue';
import { useMcpServers } from 'dashboard/components-next/captain/pageComponents/mcpServer/useMcpServers';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';

const store = useStore();
const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { isFeatureFlagEnabled, shouldShowPaywall } = usePolicy();
const { isAdmin } = useAdmin();

const SOFT_LIMIT = 10;
const isV2 = computed(() => isFeatureFlagEnabled(FEATURE_FLAGS.CAPTAIN_V2));

const uiFlags = useMapGetter('captainCustomTools/getUIFlags');
const customTools = useMapGetter('captainCustomTools/getRecords');
const isFetching = computed(() => uiFlags.value.fetchingList);
const customToolsMeta = useMapGetter('captainCustomTools/getMeta');

const mcp = useMcpServers();
const mcpServers = mcp.servers;

// MCP servers sit on the same page as custom tools: both are things the AI agent can call.
const mcpDialogRef = ref(null);
const mcpDialogServer = ref(undefined); // undefined: closed, null: new server
const mcpBusyIds = ref(new Set());
const mcpToDelete = ref(null);
const mcpDeleteDialogRef = ref(null);

const isPageFetching = computed(() => isFetching.value || mcp.isFetching.value);

const mcpError = error =>
  useAlert(parseAPIErrorResponse(error) || t('CAPTAIN.MCP_SERVERS.ERROR'));

const openMcpDialog = (server = null) => {
  mcpDialogServer.value = server;
  nextTick(() => mcpDialogRef.value.dialogRef.open());
};

const withMcpBusy = async (id, action) => {
  mcpBusyIds.value = new Set([...mcpBusyIds.value, id]);
  try {
    await action();
  } catch (error) {
    mcpError(error);
  } finally {
    const next = new Set(mcpBusyIds.value);
    next.delete(id);
    mcpBusyIds.value = next;
  }
};

const handleMcpAction = ({ action, server }) => {
  if (action === 'edit') openMcpDialog(server);
  if (action === 'delete') {
    mcpToDelete.value = server;
    nextTick(() => mcpDeleteDialogRef.value.open());
  }
  if (action === 'refresh') {
    withMcpBusy(server.id, async () => {
      const updated = await mcp.refreshTools(server.id);
      if (updated.status === 'failed') useAlert(updated.last_error);
    });
  }
};

const toggleMcpTool = ({ server, tool, enabled }) =>
  withMcpBusy(server.id, () =>
    mcp.setEnabledTools(
      server.id,
      server.tools
        .filter(item => (item.name === tool.name ? enabled : item.enabled))
        .map(item => item.name)
    )
  );

const deleteMcpServer = () =>
  withMcpBusy(mcpToDelete.value.id, async () => {
    await mcp.remove(mcpToDelete.value.id);
    mcpDeleteDialogRef.value.close();
    mcpToDelete.value = null;
  });

const showSoftLimitWarning = computed(
  () => !isV2.value && customToolsMeta.value.totalCount > SOFT_LIMIT
);

const deleteDialogRef = ref(null);
const disableDialogRef = ref(null);
const selectedTool = ref(null);
const pendingToggleIds = ref(new Set());
const pendingDisable = ref(null);
const isDisableSaving = ref(false);

const disableConfirmationTitle = computed(() =>
  t('CAPTAIN.CUSTOM_TOOLS.DISABLE_CONFIRMATION.TITLE', {
    title: pendingDisable.value?.title,
  })
);

const disableConfirmationDescription = computed(() => {
  const count = pendingDisable.value?.enabledScenariosCount || 0;
  return count === 1
    ? t('CAPTAIN.CUSTOM_TOOLS.DISABLE_CONFIRMATION.DESCRIPTION_ONE', {
        count,
      })
    : t('CAPTAIN.CUSTOM_TOOLS.DISABLE_CONFIRMATION.DESCRIPTION_OTHER', {
        count,
      });
});

const setTogglePending = (id, isPending) => {
  const pendingIds = new Set(pendingToggleIds.value);
  if (isPending) {
    pendingIds.add(id);
  } else {
    pendingIds.delete(id);
  }
  pendingToggleIds.value = pendingIds;
};

const fetchCustomTools = (page = 1) => {
  store.dispatch('captainCustomTools/get', { page });
};

const onPageChange = page => fetchCustomTools(page);

// Actions are created and edited on their own page, which has room for the steps and the test panel.
const openCreateDialog = () =>
  router.push({ name: 'captain_tools_new', params: route.params });

const handleEdit = tool =>
  router.push({
    name: 'captain_tools_edit',
    params: { ...route.params, toolId: tool.id },
  });

const handleDelete = tool => {
  selectedTool.value = tool;
  nextTick(() => deleteDialogRef.value.dialogRef.open());
};

const handleAction = ({ action, id }) => {
  const tool = customTools.value.find(item => item.id === id);
  if (action === 'edit') {
    handleEdit(tool);
  } else if (action === 'delete') {
    handleDelete(tool);
  }
};

const updateCustomToolStatus = async ({ id, enabled }) => {
  try {
    await store.dispatch('captainCustomTools/update', { id, enabled });
    const successMessage = enabled
      ? t('CAPTAIN.CUSTOM_TOOLS.TOGGLE.ENABLED')
      : t('CAPTAIN.CUSTOM_TOOLS.TOGGLE.DISABLED');
    useAlert(successMessage);
    return true;
  } catch {
    useAlert(t('CAPTAIN.CUSTOM_TOOLS.TOGGLE.ERROR'));
    return false;
  }
};

const toggleCustomTool = async ({ id, enabled }) => {
  if (pendingToggleIds.value.has(id)) return;

  setTogglePending(id, true);

  if (!enabled) {
    try {
      const tool = await store.dispatch('captainCustomTools/show', id);
      if (tool.enabled_scenarios_count > 0) {
        pendingDisable.value = {
          id,
          enabled,
          title: tool.title,
          enabledScenariosCount: tool.enabled_scenarios_count,
        };
        await nextTick();
        disableDialogRef.value?.open();
        return;
      }
    } catch {
      useAlert(t('CAPTAIN.CUSTOM_TOOLS.TOGGLE.ERROR'));
      setTogglePending(id, false);
      return;
    }
  }

  await updateCustomToolStatus({ id, enabled });
  setTogglePending(id, false);
};

const handleDisableConfirm = async () => {
  if (!pendingDisable.value) return;

  isDisableSaving.value = true;
  const updated = await updateCustomToolStatus(pendingDisable.value);
  isDisableSaving.value = false;

  if (updated) disableDialogRef.value?.close();
};

const handleDisableDialogClose = () => {
  if (pendingDisable.value) {
    setTogglePending(pendingDisable.value.id, false);
  }
  pendingDisable.value = null;
  isDisableSaving.value = false;
};

const onDeleteSuccess = () => {
  selectedTool.value = null;
  // Check if page will be empty after deletion
  if (customTools.value.length === 1 && customToolsMeta.value.page > 1) {
    // Go to previous page if current page will be empty
    onPageChange(customToolsMeta.value.page - 1);
  } else {
    // Refresh current page
    fetchCustomTools(customToolsMeta.value.page);
  }
};

onMounted(() => {
  if (!shouldShowPaywall(FEATURE_FLAGS.CAPTAIN_CUSTOM_TOOLS)) {
    fetchCustomTools();
    if (isAdmin.value) mcp.fetch().catch(mcpError);
  }
});

// One route per tab: built-in tools, email templates, API calls and MCP servers.
const VIEWS = {
  captain_tools_index: 'BUILT_IN',
  captain_tools_email_templates: 'EMAIL_TEMPLATES',
  captain_tools_api: 'API_CALLS',
  captain_tools_connections: 'MCP',
};
const view = computed(() => VIEWS[route.name] || 'BUILT_IN');
watch(
  view,
  currentView => {
    if (currentView === 'MCP' && isAdmin.value) {
      mcp.fetch().catch(mcpError);
    }
  },
  { immediate: true }
);

const emailTemplatesRef = ref(null);
const headerButtonLabel = computed(
  () =>
    ({
      EMAIL_TEMPLATES: t('CAPTAIN.AGENT_UX.TOOLS.NEW_TEMPLATE'),
      API_CALLS: t('CAPTAIN.CUSTOM_TOOLS.ADD_NEW'),
      MCP: t('CAPTAIN.MCP_SERVERS.ADD'),
    })[view.value] || ''
);
const onHeaderButton = () => {
  if (view.value === 'MCP') openMcpDialog();
  else if (view.value === 'EMAIL_TEMPLATES') emailTemplatesRef.value?.open();
  else openCreateDialog();
};
</script>

<template>
  <PageLayout
    :header-title="$t('CAPTAIN.AGENT_UX.SECTIONS.ACTIONS')"
    :button-label="headerButtonLabel"
    :button-policy="['administrator']"
    :feature-flag="FEATURE_FLAGS.CAPTAIN_CUSTOM_TOOLS"
    :total-count="customToolsMeta.totalCount"
    :current-page="customToolsMeta.page"
    :show-pagination-footer="
      view === 'API_CALLS' && !isFetching && customToolsMeta.totalCount > 25
    "
    :is-fetching="isPageFetching"
    :is-empty="false"
    :show-know-more="false"
    @update:current-page="onPageChange"
    @click="onHeaderButton"
  >
    <template #paywall>
      <CaptainPaywall feature-prefix="CAPTAIN.CUSTOM_TOOLS" />
    </template>

    <template #body>
      <div class="flex flex-col gap-5 pb-8">
        <div
          v-if="view === 'API_CALLS' && showSoftLimitWarning"
          class="flex items-center gap-2 px-4 py-3 text-sm rounded-lg bg-n-amber-2 text-n-amber-11"
        >
          <span class="i-lucide-triangle-alert size-4 shrink-0" />
          {{ $t('CAPTAIN.CUSTOM_TOOLS.SOFT_LIMIT_WARNING') }}
        </div>

        <BuiltInActionsSection v-if="view === 'BUILT_IN'" />

        <EmailTemplatesSection
          v-else-if="view === 'EMAIL_TEMPLATES'"
          ref="emailTemplatesRef"
        />

        <template v-else-if="view === 'API_CALLS'">
          <p class="max-w-3xl m-0 text-sm text-n-slate-11">
            {{ $t('CAPTAIN.AGENT_UX.TOOLS.INTRO.API_CALLS') }}
          </p>
          <div
            v-if="!customTools.length"
            class="flex flex-col items-center gap-3 px-6 py-10 text-center border border-dashed rounded-xl border-n-strong"
            data-test="custom-actions-empty"
          >
            <span class="i-lucide-webhook size-6 text-n-slate-10" />
            <p class="m-0 text-sm text-n-slate-11">
              {{ $t('CAPTAIN.AGENT_UX.TOOLS.API_EMPTY') }}
            </p>
          </div>
          <CustomToolCard
            v-for="tool in customTools"
            :id="tool.id"
            :key="tool.id"
            :title="tool.title"
            :description="tool.description"
            :endpoint-url="tool.endpoint_url"
            :http-method="tool.http_method"
            :auth-type="tool.auth_type"
            :param-schema="tool.param_schema"
            :enabled="tool.enabled"
            :is-updating="pendingToggleIds.has(tool.id)"
            :created-at="tool.created_at"
            :updated-at="tool.updated_at"
            @action="handleAction"
            @toggle="toggleCustomTool"
          />
        </template>

        <template v-else>
          <p class="max-w-3xl m-0 text-sm text-n-slate-11">
            {{ $t('CAPTAIN.AGENT_UX.TOOLS.INTRO.MCP') }}
          </p>
          <div
            v-if="!mcpServers.length"
            class="flex flex-col items-center gap-3 px-6 py-10 text-center border border-dashed rounded-xl border-n-strong"
          >
            <span class="i-lucide-plug size-6 text-n-slate-10" />
            <p class="m-0 text-sm text-n-slate-11">
              {{ $t('CAPTAIN.AGENT_UX.TOOLS.MCP_EMPTY') }}
            </p>
          </div>
          <McpServerCard
            v-for="server in mcpServers"
            :key="server.id"
            :server="server"
            :is-updating="mcpBusyIds.has(server.id)"
            @action="handleMcpAction"
            @toggle-tool="toggleMcpTool"
          />
        </template>
      </div>
    </template>
  </PageLayout>

  <ConnectMcpServerDialog
    v-if="mcpDialogServer !== undefined"
    ref="mcpDialogRef"
    :server="mcpDialogServer"
    :save="mcp.save"
    :set-enabled-tools="mcp.setEnabledTools"
    @close="mcpDialogServer = undefined"
  />

  <DeleteDialog
    v-if="selectedTool"
    ref="deleteDialogRef"
    :entity="selectedTool"
    type="CustomTools"
    translation-key="CUSTOM_TOOLS"
    @delete-success="onDeleteSuccess"
  />

  <Dialog
    ref="disableDialogRef"
    type="alert"
    :title="disableConfirmationTitle"
    :description="disableConfirmationDescription"
    :confirm-button-label="
      t('CAPTAIN.CUSTOM_TOOLS.DISABLE_CONFIRMATION.CONFIRM')
    "
    :is-loading="isDisableSaving"
    @confirm="handleDisableConfirm"
    @close="handleDisableDialogClose"
  />

  <Dialog
    ref="mcpDeleteDialogRef"
    type="alert"
    :title="
      t('CAPTAIN.MCP_SERVERS.DELETE_CONFIRM.TITLE', {
        name: mcpToDelete?.name,
      })
    "
    :description="t('CAPTAIN.MCP_SERVERS.DELETE_CONFIRM.DESCRIPTION')"
    :confirm-button-label="t('CAPTAIN.MCP_SERVERS.DELETE')"
    @confirm="deleteMcpServer"
  />
</template>

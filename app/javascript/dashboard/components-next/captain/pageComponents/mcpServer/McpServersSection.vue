<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import api from 'dashboard/api/captain/mcpServers';
import Button from 'dashboard/components-next/button/Button.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import McpServerForm from './McpServerForm.vue';

// Remote MCP servers: connect one, then enable the tools scenarios may call. New tools start disabled.
const { t } = useI18n();

const servers = ref([]);
const editingId = ref(null); // 'new' while adding a server
const isSaving = ref(false);
const busyIds = ref(new Set());
const serverToDelete = ref(null);
const deleteDialogRef = ref(null);

const errorMessage = error =>
  error?.response?.data?.message ||
  error?.response?.data?.error ||
  t('CAPTAIN.MCP_SERVERS.ERROR');

const replaceServer = server => {
  const index = servers.value.findIndex(item => item.id === server.id);
  if (index === -1) servers.value.push(server);
  else servers.value.splice(index, 1, server);
};

const withBusy = async (id, action) => {
  busyIds.value = new Set([...busyIds.value, id]);
  try {
    await action();
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    const next = new Set(busyIds.value);
    next.delete(id);
    busyIds.value = next;
  }
};

const fetchServers = async () => {
  try {
    const { data } = await api.get();
    servers.value = data.payload;
  } catch (error) {
    useAlert(errorMessage(error));
  }
};

const save = async payload => {
  isSaving.value = true;
  try {
    const { data } =
      editingId.value === 'new'
        ? await api.create(payload)
        : await api.update(editingId.value, payload);
    replaceServer(data);
    editingId.value = null;
    if (data.status === 'failed') useAlert(data.last_error);
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isSaving.value = false;
  }
};

const refreshTools = server =>
  withBusy(server.id, async () => {
    const { data } = await api.sync(server.id);
    replaceServer(data);
    if (data.status === 'failed') useAlert(data.last_error);
  });

const toggleTool = (server, tool, enabled) =>
  withBusy(server.id, async () => {
    const names = server.tools
      .filter(item => (item.name === tool.name ? enabled : item.enabled))
      .map(item => item.name);
    const { data } = await api.update(server.id, { enabled_tool_names: names });
    replaceServer(data);
  });

const confirmDelete = server => {
  serverToDelete.value = server;
  deleteDialogRef.value?.open();
};

const deleteServer = () =>
  withBusy(serverToDelete.value.id, async () => {
    await api.delete(serverToDelete.value.id);
    servers.value = servers.value.filter(
      item => item.id !== serverToDelete.value.id
    );
    deleteDialogRef.value?.close();
    serverToDelete.value = null;
  });

onMounted(fetchServers);
</script>

<template>
  <section class="flex flex-col gap-4 pt-6 border-t border-n-weak">
    <div class="flex items-start justify-between gap-4">
      <div class="flex flex-col gap-1">
        <h2 class="text-base font-semibold text-n-slate-12">
          {{ t('CAPTAIN.MCP_SERVERS.TITLE') }}
        </h2>
        <p class="m-0 text-sm text-n-slate-11">
          {{ t('CAPTAIN.MCP_SERVERS.DESCRIPTION') }}
        </p>
      </div>
      <Button
        v-if="editingId !== 'new'"
        :label="t('CAPTAIN.MCP_SERVERS.ADD')"
        icon="i-lucide-plug"
        size="sm"
        variant="faded"
        @click="editingId = 'new'"
      />
    </div>

    <McpServerForm
      v-if="editingId === 'new'"
      :is-saving="isSaving"
      @submit="save"
      @cancel="editingId = null"
    />

    <p
      v-if="!servers.length && editingId !== 'new'"
      class="m-0 text-sm text-n-slate-10"
    >
      {{ t('CAPTAIN.MCP_SERVERS.EMPTY') }}
    </p>

    <article
      v-for="server in servers"
      :key="server.id"
      class="flex flex-col gap-3 p-4 rounded-xl bg-n-solid-1 outline outline-1 outline-n-weak"
    >
      <div class="flex items-start justify-between gap-3">
        <div class="flex flex-col min-w-0 gap-1">
          <div class="flex items-center gap-2">
            <span class="font-medium truncate text-n-slate-12">
              {{ server.name }}
            </span>
            <span
              class="px-2 py-0.5 text-xs rounded-full"
              :class="
                server.status === 'connected'
                  ? 'bg-n-teal-3 text-n-teal-11'
                  : 'bg-n-ruby-3 text-n-ruby-11'
              "
            >
              {{
                t(`CAPTAIN.MCP_SERVERS.STATUS.${server.status.toUpperCase()}`)
              }}
            </span>
          </div>
          <span class="text-xs truncate text-n-slate-11">
            {{ server.endpoint_url }}
          </span>
          <span
            v-if="server.status === 'failed' && server.last_error"
            class="text-xs text-n-ruby-11"
          >
            {{ server.last_error }}
          </span>
        </div>
        <div class="flex items-center gap-1 shrink-0">
          <Button
            v-tooltip="t('CAPTAIN.MCP_SERVERS.REFRESH')"
            icon="i-lucide-refresh-cw"
            size="xs"
            variant="ghost"
            color="slate"
            :aria-label="t('CAPTAIN.MCP_SERVERS.REFRESH')"
            :is-loading="busyIds.has(server.id)"
            @click="refreshTools(server)"
          />
          <Button
            v-tooltip="t('CAPTAIN.MCP_SERVERS.EDIT')"
            icon="i-lucide-pencil-line"
            size="xs"
            variant="ghost"
            color="slate"
            :aria-label="t('CAPTAIN.MCP_SERVERS.EDIT')"
            @click="editingId = server.id"
          />
          <Button
            v-tooltip="t('CAPTAIN.MCP_SERVERS.DELETE')"
            icon="i-lucide-trash-2"
            size="xs"
            variant="ghost"
            color="ruby"
            :aria-label="t('CAPTAIN.MCP_SERVERS.DELETE')"
            @click="confirmDelete(server)"
          />
        </div>
      </div>

      <McpServerForm
        v-if="editingId === server.id"
        :server="server"
        :is-saving="isSaving"
        @submit="save"
        @cancel="editingId = null"
      />

      <ul v-if="server.tools.length" class="flex flex-col gap-2 p-0 m-0">
        <li
          v-for="tool in server.tools"
          :key="tool.name"
          class="flex items-start justify-between gap-3 list-none"
        >
          <div class="flex flex-col min-w-0">
            <span class="text-sm font-medium text-n-slate-12">
              {{ tool.title }}
            </span>
            <span
              v-if="tool.description"
              class="text-xs text-n-slate-11 line-clamp-2"
            >
              {{ tool.description }}
            </span>
          </div>
          <Switch
            :model-value="tool.enabled"
            :disabled="busyIds.has(server.id)"
            @update:model-value="toggleTool(server, tool, $event)"
          />
        </li>
      </ul>
      <p
        v-else-if="server.status === 'connected'"
        class="m-0 text-sm text-n-slate-10"
      >
        {{ t('CAPTAIN.MCP_SERVERS.NO_TOOLS') }}
      </p>
      <p
        v-if="server.tools.some(tool => tool.enabled)"
        class="m-0 text-xs text-n-slate-10"
      >
        {{ t('CAPTAIN.MCP_SERVERS.SCENARIO_HINT') }}
      </p>
    </article>

    <Dialog
      ref="deleteDialogRef"
      type="alert"
      :title="
        t('CAPTAIN.MCP_SERVERS.DELETE_CONFIRM.TITLE', {
          name: serverToDelete?.name,
        })
      "
      :description="t('CAPTAIN.MCP_SERVERS.DELETE_CONFIRM.DESCRIPTION')"
      :confirm-button-label="t('CAPTAIN.MCP_SERVERS.DELETE')"
      @confirm="deleteServer"
    />
  </section>
</template>

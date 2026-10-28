import { ref } from 'vue';
import api from 'dashboard/api/captain/mcpServers';

// MCP servers of the account, shared by the Actions & MCP page, its cards and the connect dialog.
export function useMcpServers() {
  const servers = ref([]);
  const isFetching = ref(false);

  const replace = server => {
    const index = servers.value.findIndex(item => item.id === server.id);
    if (index === -1) servers.value.push(server);
    else servers.value.splice(index, 1, server);
    return server;
  };

  const fetch = async () => {
    isFetching.value = true;
    try {
      const { data } = await api.get();
      servers.value = data.payload;
    } finally {
      isFetching.value = false;
    }
  };

  const save = async (id, payload) => {
    const { data } = id
      ? await api.update(id, payload)
      : await api.create(payload);
    return replace(data);
  };

  const setEnabledTools = async (id, names) =>
    replace((await api.update(id, { enabled_tool_names: names })).data);

  const refreshTools = async id => replace((await api.sync(id)).data);

  const remove = async id => {
    await api.delete(id);
    servers.value = servers.value.filter(item => item.id !== id);
  };

  return {
    servers,
    isFetching,
    fetch,
    save,
    setEnabledTools,
    refreshTools,
    remove,
  };
}

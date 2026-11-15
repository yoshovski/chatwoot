<script setup>
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys -- Role and permission keys come from fixed API values. */
import { useAlert } from 'dashboard/composables';
import { computed, onMounted, ref } from 'vue';
import Avatar from 'next/avatar/Avatar.vue';
import { useI18n } from 'vue-i18n';
import AgentAPI from 'dashboard/api/agents';
import {
  useStoreGetters,
  useStore,
  useMapGetter,
} from 'dashboard/composables/store';

import AddAgent from './AddAgent.vue';
import EditAgent from './EditAgent.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import PageHeader from 'next/kit/PageHeader.vue';
import TableCard from 'next/kit/TableCard.vue';

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();

const loading = ref({});
const showAddPopup = ref(false);
const showDeletePopup = ref(false);
const showEditPopup = ref(false);
const agentAPI = ref({ message: '' });
const currentAgent = ref({});
const isFetching = ref(true);
const fetchFailed = ref(false);

const deleteConfirmText = computed(
  () => `${t('AGENT_MGMT.DELETE.CONFIRM.YES')} ${currentAgent.value.name}`
);
const deleteRejectText = computed(() => {
  return `${t('AGENT_MGMT.DELETE.CONFIRM.NO')} ${currentAgent.value.name}`;
});
const deleteMessage = computed(() => {
  return ` ${currentAgent.value.name}?`;
});

const agentList = computed(() => getters['agents/getAgents'].value);

const columns = computed(() => [
  { key: 'name', label: t('AGENT_MGMT.PAGE.COLUMNS.NAME') },
  { key: 'role', label: t('AGENT_MGMT.PAGE.COLUMNS.ROLE') },
  { key: 'status', label: t('AGENT_MGMT.PAGE.COLUMNS.STATUS') },
  {
    key: 'actions',
    label: t('AGENT_MGMT.PAGE.COLUMNS.ACTIONS'),
    end: true,
    hideLabel: true,
  },
]);
const currentUserId = computed(() => getters.getCurrentUserID.value);
const customRoles = useMapGetter('customRole/getCustomRoles');

// Loaded here, not through the store action, so the page can show a failed load.
const loadAgents = async () => {
  isFetching.value = true;
  fetchFailed.value = false;
  try {
    const { data } = await AgentAPI.get();
    store.commit('agents/SET_AGENTS', data);
  } catch {
    fetchFailed.value = true;
  } finally {
    isFetching.value = false;
  }
};

onMounted(() => {
  loadAgents();
  store.dispatch('customRole/getCustomRole');
});

const findCustomRole = agent =>
  customRoles.value.find(role => role.id === agent.custom_role_id);

const getAgentRoleName = agent => {
  if (!agent.custom_role_id) {
    return t(`AGENT_MGMT.AGENT_TYPES.${agent.role.toUpperCase()}`);
  }
  const customRole = findCustomRole(agent);
  return customRole ? customRole.name : '';
};

const getAgentRolePermissions = agent => {
  if (!agent.custom_role_id) {
    return '';
  }
  const customRole = findCustomRole(agent);
  return (customRole?.permissions || [])
    .map(permission => t(`CUSTOM_ROLE.PERMISSIONS.${permission.toUpperCase()}`))
    .join(', ');
};

const verifiedAdministrators = computed(() => {
  return agentList.value.filter(
    agent => agent.role === 'administrator' && agent.confirmed
  );
});

const showEditAction = agent => {
  return currentUserId.value !== agent.id;
};

const showDeleteAction = agent => {
  if (currentUserId.value === agent.id) {
    return false;
  }

  if (!agent.confirmed) {
    return true;
  }

  if (agent.role === 'administrator') {
    return verifiedAdministrators.value.length !== 1;
  }
  return true;
};

const showAlertMessage = message => {
  loading.value[currentAgent.value.id] = false;
  currentAgent.value = {};
  agentAPI.value.message = message;
  useAlert(message);
};

const openAddPopup = () => {
  showAddPopup.value = true;
};
const hideAddPopup = () => {
  showAddPopup.value = false;
};

const openEditPopup = agent => {
  showEditPopup.value = true;
  currentAgent.value = agent;
};
const hideEditPopup = () => {
  showEditPopup.value = false;
};

const openDeletePopup = agent => {
  showDeletePopup.value = true;
  currentAgent.value = agent;
};
const closeDeletePopup = () => {
  showDeletePopup.value = false;
};

const deleteAgent = async id => {
  try {
    await store.dispatch('agents/delete', id);
    showAlertMessage(t('AGENT_MGMT.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    showAlertMessage(t('AGENT_MGMT.DELETE.API.ERROR_MESSAGE'));
  }
};
const confirmDeletion = () => {
  loading.value[currentAgent.value.id] = true;
  closeDeletePopup();
  deleteAgent(currentAgent.value.id);
};
</script>

<template>
  <section class="flex w-full min-w-0 flex-col gap-5 pb-5 pt-2">
    <PageHeader
      :title="t('AGENT_MGMT.PAGE.TITLE')"
      :description="t('AGENT_MGMT.PAGE.SUBTITLE')"
    >
      <template #action>
        <Button
          :label="t('AGENT_MGMT.PAGE.INVITE')"
          icon="i-lucide-user-plus"
          size="sm"
          @click="openAddPopup"
        />
      </template>
    </PageHeader>

    <TableCard
      :columns="columns"
      :rows="agentList"
      :loading="isFetching && !agentList.length"
      :error="fetchFailed"
      :search-keys="['name', 'email']"
      :search-placeholder="t('AGENT_MGMT.PAGE.SEARCH')"
      :count="t('AGENT_MGMT.PAGE.COUNT', { n: agentList.length })"
      :loading-text="t('AGENT_MGMT.PAGE.LOADING')"
      :error-text="t('AGENT_MGMT.PAGE.LOAD_ERROR')"
      :retry-label="t('AGENT_MGMT.PAGE.RETRY')"
      :empty-title="t('AGENT_MGMT.PAGE.EMPTY_TITLE')"
      :empty-description="t('AGENT_MGMT.PAGE.EMPTY_DESCRIPTION')"
      empty-icon="i-lucide-users"
      :no-results-text="t('AGENT_MGMT.PAGE.NO_RESULTS')"
      @retry="loadAgents"
    >
      <template #empty>
        <Button
          :label="t('AGENT_MGMT.PAGE.INVITE')"
          icon="i-lucide-user-plus"
          size="sm"
          @click="openAddPopup"
        />
      </template>
      <template #cell-name="{ row: agent }">
        <div class="flex items-center gap-3">
          <Avatar
            :src="agent.thumbnail"
            :name="agent.name"
            :status="agent.availability_status"
            :size="32"
            hide-offline-status
          />
          <div class="flex min-w-0 flex-col">
            <span class="truncate font-medium text-n-slate-12">
              {{ agent.name }}
              <span
                v-if="agent.id === currentUserId"
                class="ms-1 text-xs font-normal text-n-slate-10"
              >
                {{ t('AGENT_MGMT.PAGE.YOU') }}
              </span>
            </span>
            <span class="truncate text-xs text-n-slate-11">
              {{ agent.email }}
            </span>
          </div>
        </div>
      </template>
      <template #cell-role="{ row: agent }">
        <span
          v-tooltip.top="getAgentRolePermissions(agent)"
          :class="{
            'cursor-help underline decoration-dotted': agent.custom_role_id,
          }"
        >
          {{ getAgentRoleName(agent) }}
        </span>
      </template>
      <template #cell-status="{ row: agent }">
        <span
          class="inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-medium"
          :class="
            agent.confirmed
              ? 'bg-n-teal-3 text-n-teal-11'
              : 'bg-n-amber-3 text-n-amber-11'
          "
        >
          <span
            class="size-1.5 rounded-full"
            :class="agent.confirmed ? 'bg-n-teal-9' : 'bg-n-amber-9'"
          />
          {{
            agent.confirmed
              ? t('AGENT_MGMT.PAGE.ACTIVE')
              : t('AGENT_MGMT.PAGE.INVITED')
          }}
        </span>
      </template>
      <template #cell-actions="{ row: agent }">
        <div class="flex justify-end gap-1">
          <Button
            v-if="showEditAction(agent)"
            v-tooltip.top="t('AGENT_MGMT.EDIT.BUTTON_TEXT')"
            :aria-label="t('AGENT_MGMT.EDIT.BUTTON_TEXT')"
            icon="i-lucide-pencil"
            variant="ghost"
            color="slate"
            size="sm"
            @click="openEditPopup(agent)"
          />
          <Button
            v-if="showDeleteAction(agent)"
            v-tooltip.top="t('AGENT_MGMT.DELETE.BUTTON_TEXT')"
            :aria-label="t('AGENT_MGMT.DELETE.BUTTON_TEXT')"
            icon="i-lucide-trash-2"
            variant="ghost"
            color="ruby"
            size="sm"
            :is-loading="loading[agent.id]"
            @click="openDeletePopup(agent)"
          />
        </div>
      </template>
    </TableCard>

    <woot-modal v-model:show="showAddPopup" :on-close="hideAddPopup">
      <AddAgent @close="hideAddPopup" />
    </woot-modal>

    <woot-modal v-model:show="showEditPopup" :on-close="hideEditPopup">
      <EditAgent
        v-if="showEditPopup"
        :id="currentAgent.id"
        :name="currentAgent.name"
        :provider="currentAgent.provider"
        :type="currentAgent.role"
        :email="currentAgent.email"
        :availability="currentAgent.availability_status"
        :custom-role-id="currentAgent.custom_role_id"
        @close="hideEditPopup"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeletePopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="t('AGENT_MGMT.DELETE.CONFIRM.TITLE')"
      :message="t('AGENT_MGMT.DELETE.CONFIRM.MESSAGE')"
      :message-value="deleteMessage"
      :confirm-text="deleteConfirmText"
      :reject-text="deleteRejectText"
    />
  </section>
</template>

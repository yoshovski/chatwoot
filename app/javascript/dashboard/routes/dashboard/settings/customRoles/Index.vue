<script setup>
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys -- Permission keys come from fixed API values. */
import { useAlert } from 'dashboard/composables';
import CustomRoleModal from './component/CustomRoleModal.vue';
import CustomRolePaywall from './component/CustomRolePaywall.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import CustomRoleAPI from 'dashboard/api/customRole';
import { getI18nKey } from 'dashboard/routes/dashboard/settings/helper/settingsHelper';
import PageHeader from 'next/kit/PageHeader.vue';
import SectionCard from 'next/kit/SectionCard.vue';
import TableCard from 'next/kit/TableCard.vue';

const store = useStore();
const { t } = useI18n();

const showCustomRoleModal = ref(false);
const customRoleModalMode = ref('add');
const selectedRole = ref(null);
const loading = ref({});
const showDeleteConfirmationPopup = ref(false);
const activeResponse = ref({});
const isFetching = ref(true);
const fetchFailed = ref(false);

const records = useMapGetter('customRole/getCustomRoles');

const deleteConfirmText = computed(
  () => `${t('CUSTOM_ROLE.DELETE.CONFIRM.YES')} ${activeResponse.value.name}`
);

const deleteRejectText = computed(
  () => `${t('CUSTOM_ROLE.DELETE.CONFIRM.NO')} ${activeResponse.value.name}`
);

const deleteMessage = computed(() => {
  return ` ${activeResponse.value.name} ? `;
});

const isFeatureEnabledOnAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const currentAccountId = useMapGetter('getCurrentAccountId');

const isBehindAPaywall = computed(() => {
  return !isFeatureEnabledOnAccount.value(
    currentAccountId.value,
    'custom_roles'
  );
});

// Loaded here, not through the store action, so the page can show a failed load.
const fetchCustomRoles = async () => {
  isFetching.value = true;
  fetchFailed.value = false;
  try {
    const { data } = await CustomRoleAPI.get();
    store.commit('customRole/SET_CUSTOM_ROLE', data);
  } catch {
    fetchFailed.value = true;
  } finally {
    isFetching.value = false;
  }
};

onMounted(() => {
  fetchCustomRoles();
});

const columns = computed(() => [
  { key: 'name', label: t('CUSTOM_ROLE.PAGE.COLUMNS.NAME') },
  { key: 'permissions', label: t('CUSTOM_ROLE.PAGE.COLUMNS.PERMISSIONS') },
  {
    key: 'actions',
    label: t('CUSTOM_ROLE.PAGE.COLUMNS.ACTIONS'),
    end: true,
    hideLabel: true,
    class: 'w-24',
  },
]);

const formatPermissions = role =>
  role.permissions
    .map(permission => t(getI18nKey('CUSTOM_ROLE.PERMISSIONS', permission)))
    .join(', ');

const showAlertMessage = message => {
  loading.value[activeResponse.value.id] = false;
  activeResponse.value = {};
  useAlert(message);
};

const openAddModal = () => {
  if (isBehindAPaywall.value) return;
  customRoleModalMode.value = 'add';
  selectedRole.value = null;
  showCustomRoleModal.value = true;
};

const openEditModal = role => {
  customRoleModalMode.value = 'edit';
  selectedRole.value = role;
  showCustomRoleModal.value = true;
};

const hideCustomRoleModal = () => {
  selectedRole.value = null;
  showCustomRoleModal.value = false;
};

const openDeletePopup = response => {
  showDeleteConfirmationPopup.value = true;
  activeResponse.value = response;
};

const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const deleteCustomRole = async id => {
  try {
    await store.dispatch('customRole/deleteCustomRole', id);
    showAlertMessage(t('CUSTOM_ROLE.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    const errorMessage =
      error?.message || t('CUSTOM_ROLE.DELETE.API.ERROR_MESSAGE');
    showAlertMessage(errorMessage);
  }
};

const confirmDeletion = () => {
  loading.value[activeResponse.value.id] = true;
  closeDeletePopup();
  deleteCustomRole(activeResponse.value.id);
};
</script>

<template>
  <section class="flex w-full min-w-0 flex-col gap-5 pb-5 pt-2">
    <PageHeader
      :title="t('CUSTOM_ROLE.PAGE.TITLE')"
      :description="t('CUSTOM_ROLE.PAGE.SUBTITLE')"
    >
      <template v-if="!isBehindAPaywall" #action>
        <Button
          :label="t('CUSTOM_ROLE.PAGE.NEW')"
          icon="i-lucide-plus"
          size="sm"
          @click="openAddModal"
        />
      </template>
    </PageHeader>

    <SectionCard v-if="isBehindAPaywall">
      <CustomRolePaywall />
    </SectionCard>
    <TableCard
      v-else
      :columns="columns"
      :rows="records"
      :loading="isFetching && !records.length"
      :error="fetchFailed"
      :search-keys="['name', 'description']"
      :search-placeholder="t('CUSTOM_ROLE.PAGE.SEARCH')"
      :count="t('CUSTOM_ROLE.PAGE.COUNT', { n: records.length })"
      :loading-text="t('CUSTOM_ROLE.PAGE.LOADING')"
      :error-text="t('CUSTOM_ROLE.PAGE.LOAD_ERROR')"
      :retry-label="t('CUSTOM_ROLE.PAGE.RETRY')"
      :empty-title="t('CUSTOM_ROLE.PAGE.EMPTY_TITLE')"
      :empty-description="t('CUSTOM_ROLE.PAGE.EMPTY_DESCRIPTION')"
      empty-icon="i-lucide-shield-plus"
      :no-results-text="t('CUSTOM_ROLE.PAGE.NO_RESULTS')"
      @retry="fetchCustomRoles"
    >
      <template #empty>
        <Button
          :label="t('CUSTOM_ROLE.PAGE.NEW')"
          icon="i-lucide-plus"
          size="sm"
          @click="openAddModal"
        />
      </template>
      <template #cell-name="{ row: role }">
        <div class="flex min-w-0 flex-col">
          <span class="truncate font-medium text-n-slate-12">
            {{ role.name }}
          </span>
          <span
            v-if="role.description"
            class="truncate text-xs text-n-slate-11"
          >
            {{ role.description }}
          </span>
        </div>
      </template>
      <template #cell-permissions="{ row: role }">
        <span class="text-n-slate-11">{{ formatPermissions(role) }}</span>
      </template>
      <template #cell-actions="{ row: role }">
        <div class="flex justify-end gap-1">
          <Button
            v-tooltip.top="t('CUSTOM_ROLE.EDIT.BUTTON_TEXT')"
            :aria-label="t('CUSTOM_ROLE.EDIT.BUTTON_TEXT')"
            icon="i-lucide-pencil"
            variant="ghost"
            color="slate"
            size="sm"
            @click="openEditModal(role)"
          />
          <Button
            v-tooltip.top="t('CUSTOM_ROLE.DELETE.BUTTON_TEXT')"
            :aria-label="t('CUSTOM_ROLE.DELETE.BUTTON_TEXT')"
            icon="i-lucide-trash-2"
            variant="ghost"
            color="ruby"
            size="sm"
            :is-loading="loading[role.id]"
            @click="openDeletePopup(role)"
          />
        </div>
      </template>
    </TableCard>

    <woot-modal
      v-model:show="showCustomRoleModal"
      :on-close="hideCustomRoleModal"
    >
      <CustomRoleModal
        :mode="customRoleModalMode"
        :selected-role="selectedRole"
        @close="hideCustomRoleModal"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="t('CUSTOM_ROLE.DELETE.CONFIRM.TITLE')"
      :message="t('CUSTOM_ROLE.DELETE.CONFIRM.MESSAGE')"
      :message-value="deleteMessage"
      :confirm-text="deleteConfirmText"
      :reject-text="deleteRejectText"
    />
  </section>
</template>

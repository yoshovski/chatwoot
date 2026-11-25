<script setup>
// Translation keys are selected from the fixed mappings in this screen.
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys */
import { computed, onMounted, ref, watch, onBeforeUnmount } from 'vue';
import { useSectionHeadingMatches } from 'dashboard/composables/useSectionHeading';
import { createReusableTemplate } from '@vueuse/core';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';
import { vOnClickOutside } from '@vueuse/components';
import { useStore } from 'dashboard/composables/store';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import { useAlert } from 'dashboard/composables';
import ContactsAPI from 'dashboard/api/contacts';
import BulkActionsAPI from 'dashboard/api/bulkActions';
import PageFrame from 'dashboard/components-next/kit/PageFrame.vue';
import PageHeader from 'dashboard/components-next/kit/PageHeader.vue';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';
import SearchField from 'dashboard/components-next/kit/SearchField.vue';
import EmptyState from 'dashboard/components-next/kit/EmptyState.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import Policy from 'dashboard/components/policy.vue';
import CustomerTable from 'dashboard/components-next/Contacts/Customers/CustomerTable.vue';
import CustomerDrawer from 'dashboard/components-next/Contacts/Customers/CustomerDrawer.vue';
import SegmentEditor from 'dashboard/components-next/Contacts/Customers/SegmentEditor.vue';
import CreateNewContactDialog from 'dashboard/components-next/Contacts/ContactsForm/CreateNewContactDialog.vue';
import ContactImportDialog from 'dashboard/components-next/Contacts/ContactsForm/ContactImportDialog.vue';
import ContactExportDialog from 'dashboard/components-next/Contacts/ContactsForm/ContactExportDialog.vue';
import ContactsBulkActionBar from '../components/ContactsBulkActionBar.vue';

const { t } = useI18n();
const titleInTopBar = useSectionHeadingMatches(() => t('CUSTOMERS.TITLE'));
const [DefineCustomerActions, CustomerActions] = createReusableTemplate();
const route = useRoute();
const router = useRouter();
const store = useStore();
const { uiSettings, updateUISettings } = useUISettings();
const { run, isPending } = useAbortableRequest();
const segmentsRequest = useAbortableRequest();
const segments = ref([]);
const contacts = ref([]);
const total = ref(0);
const error = ref(false);
const segmentsError = ref(false);
const search = ref(route.query.search || '');
const selectedIds = ref([]);
const busy = ref(false);
const showColumnsMenu = ref(false);
const showMoreMenu = ref(false);
const segmentEditor = ref(null);
const drawer = ref(null);
const deleteDialog = ref(null);
const deleteSegmentDialog = ref(null);
const createDialog = ref(null);
const importDialog = ref(null);
const exportDialog = ref(null);
const columnKeys = {
  email: 'CUSTOMERS.COLUMNS.EMAIL',
  last_activity_at: 'CUSTOMERS.COLUMNS.LAST_SEEN',
  conversations_count: 'CUSTOMERS.COLUMNS.CONVERSATIONS',
  labels: 'CUSTOMERS.COLUMNS.LABELS',
  source: 'CUSTOMERS.COLUMNS.SOURCE',
};
const segmentKeys = {
  all: 'CUSTOMERS.SEGMENTS.ALL',
  online: 'CUSTOMERS.SEGMENTS.ONLINE',
  leads: 'CUSTOMERS.SEGMENTS.LEADS',
  new: 'CUSTOMERS.SEGMENTS.NEW',
  waiting: 'CUSTOMERS.SEGMENTS.WAITING',
};
const activeId = computed(() => {
  if (route.params.segmentId) return `custom:${route.params.segmentId}`;
  if (route.name === 'contacts_dashboard_active') return 'online';
  return route.query.segment || 'all';
});
const activeSegment = computed(() =>
  segments.value.find(segment => segment.id === activeId.value)
);
const segmentLabel = segment =>
  segment.built_in ? t(segmentKeys[segment.id]) : segment.name;
const title = computed(() => {
  if (route.params.label) return `#${route.params.label}`;
  return activeSegment.value
    ? segmentLabel(activeSegment.value)
    : t('CUSTOMERS.SEGMENTS.ALL');
});
const visibleSegments = computed(() =>
  segments.value.filter(
    segment => segment.id !== 'leads' || activeId.value === 'leads'
  )
);
const moreMenuItems = computed(() => [
  {
    label: t('CUSTOMERS.IMPORT'),
    action: 'import',
    value: 'import',
    icon: 'i-lucide-upload',
  },
  {
    label: t('CUSTOMERS.EXPORT'),
    action: 'export',
    value: 'export',
    icon: 'i-lucide-download',
  },
]);
const onMoreAction = ({ value }) => {
  showMoreMenu.value = false;
  if (value === 'import') importDialog.value.dialogRef.open();
  if (value === 'export') exportDialog.value.dialogRef.open();
};
const page = computed(() => Number(route.query.page) || 1);
const sort = computed(
  () => uiSettings.value.customers_sort || '-last_activity_at'
);
const columns = computed({
  get: () =>
    Object.keys(columnKeys).filter(column =>
      (uiSettings.value.customers_columns || Object.keys(columnKeys)).includes(
        column
      )
    ),
  set: value => updateUISettings({ customers_columns: value }),
});
const fetchSegments = async () => {
  segmentsError.value = false;
  try {
    const response = await segmentsRequest.run(signal =>
      ContactsAPI.segments({ signal })
    );
    if (response) segments.value = response.data.payload;
  } catch {
    segmentsError.value = true;
  }
};
const fetchCustomers = async () => {
  error.value = false;
  try {
    const response = await run(signal =>
      ContactsAPI.directory(
        {
          segment: activeId.value,
          page: page.value,
          q: route.query.search,
          sort: sort.value,
          label: route.params.label,
        },
        { signal }
      )
    );
    if (!response) return;
    contacts.value = response.data.payload;
    total.value = response.data.meta.count;
  } catch {
    error.value = true;
    contacts.value = [];
  }
};
const refresh = () => {
  fetchCustomers();
  fetchSegments();
};
const selectSegment = segment => {
  if (busy.value) return;
  selectedIds.value = [];
  search.value = '';
  router.push({
    name: segment.id.startsWith('custom:')
      ? 'contacts_dashboard_segments_index'
      : 'contacts_dashboard_index',
    params: {
      accountId: route.params.accountId,
      ...(segment.id.startsWith('custom:')
        ? { segmentId: segment.id.split(':')[1] }
        : {}),
    },
    query:
      segment.built_in && segment.id !== 'all' ? { segment: segment.id } : {},
  });
};
const updateSearch = debounce(value => {
  router.replace({
    query: { ...route.query, search: value || undefined, page: undefined },
  });
}, 250);
onBeforeUnmount(() => updateSearch.cancel?.());
const setSort = attribute => {
  updateUISettings({
    customers_sort: sort.value === attribute ? `-${attribute}` : attribute,
  });
};
const select = (id, checked) => {
  selectedIds.value = checked
    ? [...new Set([...selectedIds.value, id])]
    : selectedIds.value.filter(value => value !== id);
};
const selectAll = checked => {
  const pageIds = contacts.value.map(contact => contact.id);
  selectedIds.value = checked
    ? [...new Set([...selectedIds.value, ...pageIds])]
    : selectedIds.value.filter(id => !pageIds.includes(id));
};
const bulkAction = async payload => {
  if (busy.value || !selectedIds.value.length) return;
  busy.value = true;
  try {
    await BulkActionsAPI.create({
      type: 'Contact',
      ids: selectedIds.value,
      ...payload,
    });
    selectedIds.value = [];
    deleteDialog.value.close();
    useAlert(t('CUSTOMERS.ACTION_QUEUED'));
    refresh();
  } catch {
    useAlert(t('CUSTOMERS.ACTION_ERROR'));
  } finally {
    busy.value = false;
  }
};
const segmentSaved = async id => {
  await fetchSegments();
  if (activeId.value === `custom:${id}`) fetchCustomers();
  else selectSegment({ id: `custom:${id}`, built_in: false });
};
const deleteSegment = async () => {
  try {
    await store.dispatch('customViews/delete', {
      id: Number(route.params.segmentId),
      filterType: 'contact',
    });
    deleteSegmentDialog.value.close();
    await fetchSegments();
    selectSegment({ id: 'all', built_in: true });
  } catch {
    useAlert(t('CUSTOMERS.ACTION_ERROR'));
  }
};
const createCustomer = async contact => {
  try {
    await store.dispatch('contacts/create', contact);
    createDialog.value.onSuccess();
    refresh();
  } catch (failure) {
    useAlert(failure.message || t('CUSTOMERS.ACTION_ERROR'));
  }
};
const importCustomers = async file => {
  try {
    await store.dispatch('contacts/import', file);
    importDialog.value.dialogRef.close();
    useAlert(t('CUSTOMERS.ACTION_QUEUED'));
  } catch {
    useAlert(t('CUSTOMERS.ACTION_ERROR'));
  }
};
const exportCustomers = async query => {
  try {
    await ContactsAPI.exportContacts({
      ...query,
      segment: activeId.value,
      q: route.query.search,
      label: route.params.label,
    });
    exportDialog.value.dialogRef.close();
    useAlert(t('CUSTOMERS.ACTION_QUEUED'));
  } catch {
    useAlert(t('CUSTOMERS.ACTION_ERROR'));
  }
};
watch(
  () => [
    activeId.value,
    route.params.label,
    route.params.accountId,
    route.query.search,
  ],
  () => {
    selectedIds.value = [];
  }
);
watch(
  () => [
    activeId.value,
    page.value,
    route.query.search,
    route.params.label,
    route.params.accountId,
    sort.value,
  ],
  fetchCustomers
);
watch(
  () => route.query.search,
  value => {
    search.value = value || '';
  }
);
watch(() => route.params.accountId, fetchSegments);
onMounted(() => {
  refresh();
  store.dispatch('attributes/get');
  store.dispatch('labels/get');
});
</script>

<template>
  <PageFrame workspace size="wide">
    <template #header>
      <DefineCustomerActions>
        <Button
          color="slate"
          variant="ghost"
          icon="i-lucide-user-plus"
          :label="t('CUSTOMERS.ADD_CUSTOMER')"
          @click="createDialog.dialogRef.open()"
        />
        <Button
          icon="i-lucide-plus"
          :label="t('CUSTOMERS.NEW_SEGMENT')"
          @click="segmentEditor.open()"
        />
      </DefineCustomerActions>
      <PageHeader v-if="!titleInTopBar" :title="t('CUSTOMERS.TITLE')">
        <template #action><CustomerActions /></template>
      </PageHeader>
    </template>

    <SectionCard class="workspace-widget workspace-inset min-w-0 !gap-4">
      <div
        v-if="visibleSegments.length || segmentsError || titleInTopBar"
        class="flex flex-wrap items-center justify-between gap-2 border-b border-n-weak pb-3"
      >
        <nav
          v-if="visibleSegments.length"
          :aria-label="t('CUSTOMERS.SEGMENTS_LABEL')"
          class="inline-flex flex-wrap items-center gap-1 rounded-lg bg-n-solid-1 p-1 outline outline-1 -outline-offset-1 outline-n-container"
        >
          <button
            v-for="segment in visibleSegments"
            :key="segment.id"
            type="button"
            :aria-current="activeId === segment.id ? 'page' : undefined"
            :disabled="busy"
            class="inline-flex items-center gap-1.5 rounded-md px-3 py-1.5 text-xs font-medium transition-colors"
            :class="
              activeId === segment.id
                ? 'bg-n-solid-active text-n-slate-12 shadow-sm outline outline-1 -outline-offset-1 outline-n-container'
                : 'text-n-slate-11 hover:text-n-slate-12'
            "
            @click="selectSegment(segment)"
          >
            <span>{{ segmentLabel(segment) }}</span>
            <span class="tabular-nums text-n-slate-10">
              {{ segment.count.toLocaleString() }}
            </span>
          </button>
        </nav>
        <div
          v-if="titleInTopBar"
          class="ms-auto flex flex-wrap items-center gap-2"
        >
          <CustomerActions />
        </div>
        <div
          v-if="segmentsError"
          role="alert"
          class="flex items-center gap-2 text-xs text-n-ruby-11"
        >
          {{ t('CUSTOMERS.LOAD_ERROR') }}
          <Button
            size="xs"
            variant="ghost"
            :label="t('CUSTOMERS.RETRY')"
            @click="fetchSegments"
          />
        </div>
      </div>
      <div class="flex flex-wrap items-center gap-2">
        <h2
          class="m-0 me-auto flex items-baseline gap-2 text-base font-semibold text-n-slate-12"
        >
          {{ title }}
          <span class="text-sm font-normal tabular-nums text-n-slate-10">
            {{ total.toLocaleString() }}
          </span>
        </h2>
        <SearchField
          v-model="search"
          :placeholder="t('CUSTOMERS.SEARCH')"
          class="order-last w-full shrink-0 sm:order-none sm:w-64"
          @update:model-value="updateSearch"
        />
        <div
          v-on-click-outside="() => (showColumnsMenu = false)"
          class="relative"
          @keydown.escape="showColumnsMenu = false"
        >
          <Button
            icon="i-lucide-columns-3"
            color="slate"
            variant="solid"
            size="sm"
            :label="t('CUSTOMERS.COLUMNS_LABEL')"
            @click="showColumnsMenu = !showColumnsMenu"
          />
          <div
            v-if="showColumnsMenu"
            class="absolute end-0 top-10 z-20 w-48 rounded-card bg-n-alpha-3 p-2 shadow-lg outline outline-1 -outline-offset-1 outline-n-container backdrop-blur-[100px]"
          >
            <div
              v-for="(key, column) in columnKeys"
              :key="column"
              class="flex items-center gap-2 rounded-md px-2 py-1.5 text-xs text-n-slate-12 hover:bg-n-alpha-1"
            >
              <input
                :id="'co-' + column"
                v-model="columns"
                type="checkbox"
                :value="column"
                class="m-0"
              />
              <label :for="'co-' + column" class="cursor-pointer mb-0">{{
                t(key)
              }}</label>
            </div>
          </div>
        </div>
        <Button
          v-if="route.params.segmentId"
          icon="i-lucide-pen-line"
          color="slate"
          variant="ghost"
          size="sm"
          :aria-label="t('CUSTOMERS.EDIT_SEGMENT')"
          @click="segmentEditor.open(activeSegment)"
        />
        <Button
          v-if="route.params.segmentId"
          icon="i-lucide-trash"
          color="ruby"
          variant="ghost"
          size="sm"
          :aria-label="t('CUSTOMERS.DELETE_SEGMENT')"
          @click="deleteSegmentDialog.open()"
        />
        <Button
          icon="i-lucide-refresh-cw"
          color="slate"
          variant="ghost"
          size="sm"
          :aria-label="t('CUSTOMERS.REFRESH')"
          :disabled="busy"
          @click="refresh"
        />
        <Policy :permissions="['administrator']">
          <div
            v-on-click-outside="() => (showMoreMenu = false)"
            class="relative"
            @keydown.escape="showMoreMenu = false"
          >
            <Button
              icon="i-lucide-ellipsis"
              color="slate"
              variant="ghost"
              size="sm"
              :aria-label="t('CUSTOMERS.MORE')"
              @click="showMoreMenu = !showMoreMenu"
            />
            <DropdownMenu
              v-if="showMoreMenu"
              :menu-items="moreMenuItems"
              class="end-0 top-10 z-20"
              @action="onMoreAction"
            />
          </div>
        </Policy>
      </div>
      <ContactsBulkActionBar
        v-if="selectedIds.length"
        :visible-contact-ids="contacts.map(contact => contact.id)"
        :selected-contact-ids="selectedIds"
        :is-loading="busy"
        @toggle-all="selectAll"
        @clear-selection="selectedIds = []"
        @assign-labels="bulkAction({ labels: { add: $event } })"
        @remove-labels="bulkAction({ labels: { remove: $event } })"
        @delete-selected="deleteDialog.open()"
      />
      <div
        v-if="isPending"
        role="status"
        class="flex min-h-48 items-center justify-center gap-2 text-sm text-n-slate-11"
      >
        <Spinner />{{ t('CUSTOMERS.LOADING') }}
      </div>
      <EmptyState
        v-else-if="error"
        tone="error"
        icon="i-lucide-triangle-alert"
        :title="t('CUSTOMERS.LOAD_ERROR')"
      >
        <Button
          variant="outline"
          size="sm"
          :label="t('CUSTOMERS.RETRY')"
          @click="fetchCustomers"
        />
      </EmptyState>
      <EmptyState
        v-else-if="!contacts.length"
        icon="i-lucide-users-round"
        :title="search ? t('CUSTOMERS.NO_RESULTS') : t('CUSTOMERS.EMPTY')"
      >
        <Button
          v-if="!search && activeId === 'all'"
          color="slate"
          variant="solid"
          size="sm"
          :label="t('CUSTOMERS.ADD_CUSTOMER')"
          @click="createDialog.dialogRef.open()"
        />
      </EmptyState>
      <CustomerTable
        v-else
        :contacts="contacts"
        :columns="columns"
        :selected-ids="selectedIds"
        :sort="sort"
        :online="activeId === 'online'"
        :disabled="busy"
        @select="select"
        @select-all="selectAll"
        @open="drawer.open($event)"
        @sort="setSort"
      />
      <PaginationFooter
        v-if="!error && total > 0"
        :current-page="page"
        :total-items="total"
        :items-per-page="15"
        current-page-info="CUSTOMERS.SHOWING"
        class="relative !h-auto min-h-12 flex-wrap gap-2 !bg-transparent !px-1 !py-2 before:hidden"
        @update:current-page="
          router.replace({ query: { ...route.query, page: $event } })
        "
      />
    </SectionCard>
    <SegmentEditor ref="segmentEditor" @saved="segmentSaved" />
    <CustomerDrawer ref="drawer" />
    <CreateNewContactDialog ref="createDialog" @create="createCustomer" />
    <ContactImportDialog ref="importDialog" @import="importCustomers" />
    <ContactExportDialog ref="exportDialog" @export="exportCustomers" />
    <Dialog
      ref="deleteDialog"
      type="alert"
      :title="t('CUSTOMERS.DELETE_CUSTOMERS', { count: selectedIds.length })"
      :description="t('CUSTOMERS.DELETE_WARNING')"
      :confirm-button-label="t('CUSTOMERS.DELETE')"
      :is-loading="busy"
      :disable-confirm-button="busy"
      @confirm="bulkAction({ action_name: 'delete' })"
    />
    <Dialog
      ref="deleteSegmentDialog"
      type="alert"
      :title="t('CUSTOMERS.DELETE_SEGMENT')"
      :description="t('CUSTOMERS.DELETE_SEGMENT_WARNING')"
      :confirm-button-label="t('CUSTOMERS.DELETE')"
      @confirm="deleteSegment"
    />
  </PageFrame>
</template>

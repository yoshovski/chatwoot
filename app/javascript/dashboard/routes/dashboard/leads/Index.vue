<script setup>
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys -- Keys share a fixed namespace and come from the lead settings or status list. */
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import { downloadCsvFile } from 'dashboard/helper/downloadHelper';
import LeadsAPI from 'dashboard/api/captain/leads';
import AgentsAPI from 'dashboard/api/agents';
import PageFrame from 'dashboard/components-next/kit/PageFrame.vue';
import PageHeader from 'dashboard/components-next/kit/PageHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import LeadsTable from './LeadsTable.vue';
import LeadCaptureEntry from './LeadCaptureEntry.vue';
import { STATUSES, STATUS_TONES } from './leadsView';

const { t } = useI18n();
const router = useRouter();
const request = useAbortableRequest();
const { isPending } = request;
const leads = ref([]);
const agents = ref([]);
const agentsError = ref(false);
const error = ref(false);
const exporting = ref(false);
const savingIds = ref(new Set());
const statusFilter = ref('');
const page = ref(1);
const total = ref(0);
const counts = ref({});
const allCount = computed(() =>
  Object.values(counts.value).reduce((sum, count) => sum + count, 0)
);
const hasNext = computed(() => page.value * 25 < total.value);

const load = async () => {
  error.value = false;
  try {
    const response = await request.run(signal =>
      LeadsAPI.get({ status: statusFilter.value, page: page.value }, signal)
    );
    if (!response) return;
    leads.value = response.data.payload;
    counts.value = response.data.meta.counts;
    total.value = response.data.meta.total;
  } catch {
    error.value = true;
  }
};
const loadAgents = async () => {
  agentsError.value = false;
  try {
    const { data } = await AgentsAPI.get();
    agents.value = data;
  } catch {
    agentsError.value = true;
  }
};
watch(page, load);
watch(statusFilter, () => {
  if (page.value !== 1) page.value = 1;
  else load();
});
onMounted(() => {
  load();
  loadAgents();
});
const openLead = lead =>
  router.push({
    name: 'inbox_conversation',
    params: { conversation_id: lead.conversation_id },
  });
const updateLead = async (lead, changes) => {
  if (savingIds.value.has(lead.id)) return;
  savingIds.value.add(lead.id);
  try {
    const { data } = await LeadsAPI.update(lead.id, changes);
    const previousStatus = lead.status;
    Object.assign(lead, data);
    if (previousStatus !== data.status) {
      if (statusFilter.value && leads.value.length === 1 && page.value > 1) {
        page.value -= 1;
      } else {
        counts.value[previousStatus] -= 1;
        counts.value[data.status] = (counts.value[data.status] || 0) + 1;
        if (statusFilter.value) await load();
      }
    }
  } catch {
    useAlert(t('LEADS.SAVE_ERROR'));
  } finally {
    savingIds.value.delete(lead.id);
  }
};
const exportLeads = async () => {
  exporting.value = true;
  try {
    const { data } = await LeadsAPI.export(statusFilter.value);
    const link = downloadCsvFile('leads.csv', data);
    URL.revokeObjectURL(link.href);
  } catch {
    useAlert(t('LEADS.EXPORT_ERROR'));
  } finally {
    exporting.value = false;
  }
};
</script>

<template>
  <PageFrame size="wide">
    <template #header>
      <PageHeader :title="t('LEADS.TITLE')" :description="t('LEADS.SUBTITLE')">
        <template #action>
          <Button
            variant="faded"
            color="slate"
            size="sm"
            icon="i-lucide-download"
            :label="t('LEADS.EXPORT')"
            :is-loading="exporting"
            :disabled="isPending || error || total === 0"
            @click="exportLeads"
          />
        </template>
      </PageHeader>
    </template>

    <div
      class="flex min-w-0 flex-col rounded-card bg-n-solid-2 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
      :aria-busy="isPending"
    >
      <div
        class="flex flex-wrap items-center border-b border-n-weak px-5 py-3.5"
        role="group"
        :aria-label="t('LEADS.COLUMNS.STATUS')"
      >
        <div
          class="inline-flex flex-wrap items-center gap-1 rounded-lg bg-n-solid-1 p-1 outline outline-1 -outline-offset-1 outline-n-container"
        >
          <button
            v-for="status in ['', ...STATUSES]"
            :key="status || 'all'"
            type="button"
            class="flex items-center gap-1.5 rounded-md px-3 py-1 text-xs font-medium transition-colors"
            :class="
              statusFilter === status
                ? 'bg-n-solid-active text-n-slate-12 shadow-sm outline outline-1 -outline-offset-1 outline-n-container'
                : 'text-n-slate-11 hover:text-n-slate-12'
            "
            :aria-pressed="statusFilter === status"
            @click="statusFilter = status"
          >
            <span
              v-if="status"
              class="size-1.5 rounded-full"
              :class="STATUS_TONES[status].dot"
              aria-hidden="true"
            />
            {{
              status
                ? t(`LEADS.STATUS.${status.toUpperCase()}`)
                : t('LEADS.ALL')
            }}
            <span class="tabular-nums opacity-70">{{
              status ? counts[status] || 0 : allCount
            }}</span>
          </button>
        </div>
      </div>
      <p
        v-if="isPending"
        class="m-0 p-8 text-center text-sm text-n-slate-11"
        role="status"
      >
        {{ t('LEADS.LOADING') }}
      </p>
      <div
        v-else-if="error"
        class="flex flex-col items-center gap-3 p-8"
        role="alert"
      >
        <p class="m-0 text-sm text-n-ruby-11">{{ t('LEADS.LOAD_ERROR') }}</p>
        <Button :label="t('LEADS.RETRY')" size="sm" @click="load" />
      </div>
      <div
        v-else-if="!leads.length"
        class="flex flex-col items-center gap-3 p-8 text-center"
      >
        <p class="m-0 text-sm font-medium text-n-slate-12">
          {{ t(statusFilter ? 'LEADS.EMPTY_FILTER' : 'LEADS.EMPTY') }}
        </p>
        <LeadCaptureEntry v-if="!statusFilter" />
        <Button
          v-if="statusFilter"
          :label="t('LEADS.SHOW_ALL')"
          size="sm"
          @click="statusFilter = ''"
        />
      </div>
      <template v-else>
        <div
          v-if="agentsError"
          class="flex flex-wrap items-center justify-between gap-2 px-4 py-3"
          role="alert"
        >
          <span class="text-sm text-n-ruby-11">{{
            t('LEADS.OWNERS_ERROR')
          }}</span>
          <Button :label="t('LEADS.RETRY')" size="xs" @click="loadAgents" />
        </div>
        <LeadsTable
          :leads="leads"
          :agents="agents"
          :owners-unavailable="agentsError"
          :saving-ids="savingIds"
          @open="openLead"
          @status="(lead, status) => updateLead(lead, { status })"
          @owner="(lead, ownerId) => updateLead(lead, { owner_id: ownerId })"
        />
        <div
          class="flex items-center justify-between gap-2 border-t border-n-weak px-4 py-3"
        >
          <Button
            :label="t('LEADS.PREVIOUS')"
            variant="ghost"
            color="slate"
            size="sm"
            :disabled="page === 1"
            @click="page -= 1"
          />
          <span class="text-xs text-n-slate-11">{{
            t('LEADS.PAGE', { page, total })
          }}</span>
          <Button
            :label="t('LEADS.NEXT')"
            variant="ghost"
            color="slate"
            size="sm"
            :disabled="!hasNext"
            @click="page += 1"
          />
        </div>
      </template>
    </div>
  </PageFrame>
</template>

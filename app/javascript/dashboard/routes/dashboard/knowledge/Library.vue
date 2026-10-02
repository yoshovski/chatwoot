<script setup>
import { ref, computed, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useTimeoutPoll } from '@vueuse/core';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import api from 'dashboard/api/nativeKnowledge';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import ItemEditor from './ItemEditor.vue';
import CsvImport from './CsvImport.vue';
import { download } from './helpers';

const POLL_INTERVAL = 5000;
const { t } = useI18n();
const route = useRoute();
const { accountScopedRoute } = useAccount();
const { checkPermissions, isFeatureFlagEnabled } = usePolicy();
const canWrite = computed(() => checkPermissions(['administrator']));
const enabled = computed(() =>
  isFeatureFlagEnabled(FEATURE_FLAGS.NATIVE_AI_KNOWLEDGE)
);
const baseId = computed(() => route.params.baseId);
const bases = ref([]);
const base = ref(null);
const entries = ref([]);
const sources = ref([]);
const agents = ref([]);
const attachments = ref([]);
const tab = ref('faqs');
const search = ref('');
const error = ref('');
const busy = ref(false);
const selectedAgent = ref('');
const nameDialog = ref();
const editor = ref();
const csvDialog = ref();
const historyDialog = ref();
const name = ref('');
const editingBase = ref(null);
const history = ref([]);
const { run, abort, isPending } = useAbortableRequest();
const visibleItems = computed(() =>
  (tab.value === 'faqs' ? entries.value : sources.value).filter(item =>
    (tab.value === 'faqs'
      ? `${item.revision.question}\n${item.revision.answer}`
      : `${item.name}\n${item.revision.text}`
    )
      .toLocaleLowerCase()
      .includes(search.value.toLocaleLowerCase())
  )
);
const availableAgents = computed(() =>
  agents.value.filter(
    agent => !attachments.value.some(a => a.chatwoot_agent_bot_id === agent.id)
  )
);
const labelAgent = attachment =>
  agents.value.find(a => a.id === attachment.chatwoot_agent_bot_id)?.name ||
  t('NATIVE_KNOWLEDGE.REMOVED_AGENT');
const status = value => t(`NATIVE_KNOWLEDGE.STATUS.${value.toUpperCase()}`);
const load = async () => {
  if (!enabled.value) return;
  const scope = route.fullPath;
  try {
    const response = await run(async signal => {
      const paths = baseId.value
        ? [
            `/bases/${baseId.value}`,
            `/bases/${baseId.value}/entries`,
            `/bases/${baseId.value}/sources`,
            '/agents',
            `/bases/${baseId.value}/agents`,
          ]
        : ['/bases'];
      return Promise.all(
        paths.map(path => api.request('get', path, undefined, { signal }))
      );
    });
    if (!response || scope !== route.fullPath) return;
    if (baseId.value)
      [
        base.value,
        entries.value,
        sources.value,
        agents.value,
        attachments.value,
      ] = response.map(r => r.data);
    else bases.value = response[0].data;
    error.value = '';
  } catch {
    if (scope === route.fullPath)
      error.value = t('NATIVE_KNOWLEDGE.LOAD_ERROR');
  }
};
const { pause, resume } = useTimeoutPoll(async () => {
  if (busy.value || isPending.value) return;
  await load();
}, POLL_INTERVAL);
watch(
  () => [route.params.accountId, baseId.value, enabled.value],
  () => {
    pause();
    abort();
    bases.value = [];
    base.value = null;
    entries.value = [];
    sources.value = [];
    agents.value = [];
    attachments.value = [];
    search.value = '';
    error.value = '';
    tab.value = 'faqs';
    selectedAgent.value = '';
    load();
  },
  { immediate: true }
);
watch(
  () =>
    base.value?.index_status === 'processing' ||
    bases.value.some(b => b.index_status === 'processing'),
  pending => {
    if (pending) resume();
    else pause();
  }
);
const mutate = async callback => {
  if (busy.value || !canWrite.value) return;
  const scope = route.fullPath;
  busy.value = true;
  error.value = '';
  try {
    await callback();
    if (scope === route.fullPath) await load();
  } catch {
    if (scope === route.fullPath)
      error.value = t('NATIVE_KNOWLEDGE.SAVE_ERROR');
  } finally {
    busy.value = false;
  }
};
const openName = (record = null) => {
  editingBase.value = record;
  name.value = record?.name || '';
  nameDialog.value.open();
};
const saveName = () =>
  mutate(async () => {
    if (!name.value.length || name.value.length > 200) return;
    const record = editingBase.value;
    await api.request(
      record ? 'patch' : 'post',
      record ? `/bases/${record.id}` : '/bases',
      { name: name.value }
    );
    nameDialog.value.close();
  });
const toggleItem = item =>
  mutate(() =>
    api.request(
      'patch',
      `/${tab.value === 'faqs' ? 'entries' : 'sources'}/${item.id}/state`,
      { enabled: !item.enabled }
    )
  );
const attachAgent = () =>
  mutate(async () => {
    if (!selectedAgent.value) return;
    const url = api.url;
    const id = baseId.value;
    const { data } = await api.request(
      'post',
      '/agents',
      { chatwoot_agent_bot_id: Number(selectedAgent.value) },
      { url: `${url}/agents` }
    );
    await api.request('put', '', undefined, {
      url: `${url}/agents/${data.id}/bases/${id}`,
    });
    selectedAgent.value = '';
  });
const exportFile = async (type, revisionId = null, filename = null) => {
  const scope = route.fullPath;
  try {
    const path = revisionId
      ? `/source-revisions/${revisionId}/original`
      : `/bases/${baseId.value}/${type}`;
    const response = await api.request('get', path, undefined, {
      responseType: 'blob',
    });
    if (scope === route.fullPath)
      download(
        response.data,
        filename || (type === 'csv' ? 'faqs.csv' : 'knowledge.zip')
      );
  } catch {
    if (scope === route.fullPath)
      error.value = t('NATIVE_KNOWLEDGE.EXPORT_ERROR');
  }
};
const showHistory = async item => {
  const scope = route.fullPath;
  try {
    const { data } = await api.request(
      'get',
      `/${tab.value === 'faqs' ? 'entries' : 'sources'}/${item.id}/revisions`
    );
    if (scope !== route.fullPath) return;
    history.value = data;
    historyDialog.value.open();
  } catch {
    error.value = t('NATIVE_KNOWLEDGE.LOAD_ERROR');
  }
};
</script>

<template>
  <div
    class="flex h-full w-full flex-col overflow-auto bg-n-background p-6 text-n-slate-12"
  >
    <template v-if="enabled">
      <header class="mb-6 flex flex-wrap items-center justify-between gap-3">
        <div>
          <RouterLink
            v-if="baseId"
            :to="accountScopedRoute('native_knowledge_index')"
            class="text-sm text-n-blue-11"
          >
            {{ t('NATIVE_KNOWLEDGE.TITLE') }}
          </RouterLink>
          <h1 class="text-xl font-semibold">
            {{ baseId ? base?.name : t('NATIVE_KNOWLEDGE.TITLE') }}
          </h1>
          <p class="mt-2 text-sm text-n-slate-11">
            {{ t('NATIVE_KNOWLEDGE.DESCRIPTION') }}
          </p>
          <p v-if="base" class="mt-2 text-sm">
            {{ status(base.index_status) }}
          </p>
        </div>
        <div class="flex flex-wrap gap-2">
          <Button
            :label="t('NATIVE_KNOWLEDGE.REFRESH')"
            variant="ghost"
            icon="i-lucide-refresh-cw"
            :disabled="isPending"
            @click="load"
          />
          <Button
            v-if="!baseId && canWrite"
            :label="t('NATIVE_KNOWLEDGE.NEW_BASE')"
            icon="i-lucide-plus"
            @click="openName()"
          />
          <template v-if="base">
            <Button
              :label="t('NATIVE_KNOWLEDGE.EXPORT_CSV')"
              variant="outline"
              @click="exportFile('csv')"
            />
            <Button
              :label="t('NATIVE_KNOWLEDGE.EXPORT')"
              variant="outline"
              @click="exportFile('export')"
            />
            <Button
              v-if="canWrite && base.index_status === 'failed'"
              :label="t('NATIVE_KNOWLEDGE.RETRY')"
              variant="outline"
              :disabled="busy"
              @click="
                mutate(() => api.request('post', `/bases/${baseId}/rebuild`))
              "
            />
            <Button
              v-if="canWrite"
              :label="t('NATIVE_KNOWLEDGE.RENAME')"
              variant="ghost"
              :disabled="busy"
              @click="openName(base)"
            />
            <Button
              v-if="canWrite"
              :label="
                t(
                  base.enabled
                    ? 'NATIVE_KNOWLEDGE.DISABLE_BASE'
                    : 'NATIVE_KNOWLEDGE.ENABLE_BASE'
                )
              "
              variant="outline"
              :disabled="busy"
              @click="
                mutate(() =>
                  api.request('patch', `/bases/${baseId}`, {
                    enabled: !base.enabled,
                  })
                )
              "
            />
          </template>
        </div>
      </header>
      <p
        v-if="error"
        role="alert"
        class="mb-4 rounded-lg bg-n-ruby-3 p-3 text-sm text-n-ruby-11"
      >
        {{ error }}
      </p>
      <p
        v-if="isPending && !base && !bases.length"
        role="status"
        class="text-sm text-n-slate-11"
      >
        {{ t('NATIVE_KNOWLEDGE.LOADING') }}
      </p>
      <template v-if="!baseId">
        <p
          v-if="!isPending && !bases.length && !error"
          class="text-sm text-n-slate-11"
        >
          {{ t('NATIVE_KNOWLEDGE.EMPTY_BASES') }}
        </p>
        <div class="grid grid-cols-1 gap-4 lg:grid-cols-2 xl:grid-cols-3">
          <RouterLink
            v-for="record in bases"
            :key="record.id"
            :to="
              accountScopedRoute('native_knowledge_show', { baseId: record.id })
            "
            class="rounded-xl border border-n-weak bg-n-solid-1 p-5 hover:border-n-blue-7"
          >
            <h2 class="break-words text-lg font-medium">{{ record.name }}</h2>
            <p class="mt-3 text-sm text-n-slate-11">
              {{
                t('NATIVE_KNOWLEDGE.COUNTS', {
                  faqs: record.faq_count,
                  sources: record.source_count,
                  agents: record.agent_count,
                })
              }}
            </p>
            <p class="mt-3 text-sm">{{ status(record.index_status) }}</p>
          </RouterLink>
        </div>
      </template>
      <template v-else-if="base">
        <nav
          :aria-label="t('NATIVE_KNOWLEDGE.SECTIONS')"
          class="mb-4 flex gap-2 border-b border-n-weak pb-3"
        >
          <Button
            v-for="section in ['faqs', 'sources', 'agents']"
            :key="section"
            :label="t(`NATIVE_KNOWLEDGE.${section.toUpperCase()}`)"
            :variant="tab === section ? 'solid' : 'ghost'"
            :aria-pressed="tab === section"
            @click="
              tab = section;
              search = '';
            "
          />
        </nav>
        <template v-if="tab !== 'agents'">
          <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
            <Input v-model="search" :label="t('NATIVE_KNOWLEDGE.SEARCH')" />
            <div v-if="canWrite" class="flex gap-2">
              <Button
                v-if="tab === 'faqs'"
                :label="t('NATIVE_KNOWLEDGE.IMPORT_CSV')"
                variant="outline"
                @click="csvDialog.open()"
              />
              <Button
                :label="
                  t(
                    tab === 'faqs'
                      ? 'NATIVE_KNOWLEDGE.ADD_FAQ'
                      : 'NATIVE_KNOWLEDGE.ADD_SOURCE'
                  )
                "
                icon="i-lucide-plus"
                @click="editor.open(tab === 'faqs' ? 'faq' : 'document')"
              />
            </div>
          </div>
          <p v-if="!visibleItems.length" class="text-sm text-n-slate-11">
            {{ t('NATIVE_KNOWLEDGE.EMPTY_ITEMS') }}
          </p>
          <div class="flex flex-col gap-3">
            <article
              v-for="item in visibleItems"
              :key="item.id"
              class="rounded-xl border border-n-weak bg-n-solid-1 p-4"
            >
              <div class="flex flex-wrap items-start justify-between gap-3">
                <div class="min-w-0 flex-1">
                  <h2
                    class="whitespace-pre-wrap break-words text-sm font-semibold"
                  >
                    {{ tab === 'faqs' ? item.revision.question : item.name }}
                  </h2>
                  <p
                    class="mt-2 max-h-48 overflow-auto whitespace-pre-wrap break-words text-sm text-n-slate-11"
                  >
                    {{
                      tab === 'faqs' ? item.revision.answer : item.revision.text
                    }}
                  </p>
                  <p class="mt-3 text-xs text-n-slate-11">
                    {{ status(item.index_status) }} ·
                    {{
                      t('NATIVE_KNOWLEDGE.VERSION', { version: item.version })
                    }}
                  </p>
                </div>
                <div class="flex flex-wrap gap-2">
                  <Button
                    :label="t('NATIVE_KNOWLEDGE.HISTORY')"
                    variant="ghost"
                    @click="showHistory(item)"
                  />
                  <Button
                    v-if="tab === 'sources' && item.revision.original_sha256"
                    :label="t('NATIVE_KNOWLEDGE.DOWNLOAD_ORIGINAL')"
                    variant="ghost"
                    @click="
                      exportFile(
                        'original',
                        item.revision.id,
                        item.revision.filename
                      )
                    "
                  />
                  <Button
                    v-if="canWrite"
                    :label="t('NATIVE_KNOWLEDGE.EDIT')"
                    variant="ghost"
                    @click="
                      editor.open(tab === 'faqs' ? 'faq' : 'document', item)
                    "
                  />
                  <Button
                    v-if="canWrite"
                    :label="
                      t(
                        item.enabled
                          ? 'NATIVE_KNOWLEDGE.DISABLE'
                          : 'NATIVE_KNOWLEDGE.ENABLE'
                      )
                    "
                    variant="outline"
                    :disabled="busy"
                    @click="toggleItem(item)"
                  />
                </div>
              </div>
            </article>
          </div>
        </template>
        <template v-else>
          <p class="mb-4 text-sm text-n-slate-11">
            {{ t('NATIVE_KNOWLEDGE.AGENTS_HINT') }}
          </p>
          <div v-if="canWrite" class="mb-6 flex items-end gap-3">
            <div class="flex flex-col gap-2">
              <label for="knowledge-agent" class="text-sm">{{
                t('NATIVE_KNOWLEDGE.AGENT')
              }}</label>
              <select
                id="knowledge-agent"
                v-model="selectedAgent"
                class="rounded-lg border border-n-weak bg-n-solid-1 p-2 text-sm"
              >
                <option value="">
                  {{ t('NATIVE_KNOWLEDGE.SELECT_AGENT') }}
                </option>
                <option
                  v-for="agent in availableAgents"
                  :key="agent.id"
                  :value="agent.id"
                >
                  {{ agent.name }}
                </option>
              </select>
            </div>
            <Button
              :label="t('NATIVE_KNOWLEDGE.ATTACH')"
              :disabled="!selectedAgent || busy"
              @click="attachAgent"
            />
          </div>
          <p v-if="!attachments.length" class="text-sm text-n-slate-11">
            {{ t('NATIVE_KNOWLEDGE.EMPTY_AGENTS') }}
          </p>
          <div
            v-for="attachment in attachments"
            :key="attachment.id"
            class="mb-3 flex items-center justify-between rounded-lg border border-n-weak bg-n-solid-1 p-4"
          >
            <span>{{ labelAgent(attachment) }}</span>
            <Button
              v-if="canWrite"
              :label="t('NATIVE_KNOWLEDGE.DETACH')"
              variant="outline"
              :disabled="busy"
              @click="
                mutate(() =>
                  api.request(
                    'delete',
                    `/agents/${attachment.id}/bases/${baseId}`
                  )
                )
              "
            />
          </div>
        </template>
        <ItemEditor
          v-if="canWrite"
          :key="`editor-${route.params.accountId}-${baseId}`"
          ref="editor"
          :base-id="baseId"
          @saved="load"
        />
        <CsvImport
          v-if="canWrite"
          :key="`csv-${route.params.accountId}-${baseId}`"
          ref="csvDialog"
          :base-id="baseId"
          @saved="load"
        />
      </template>
      <Dialog
        :key="`name-${route.params.accountId}-${baseId || ''}`"
        ref="nameDialog"
        :title="
          t(
            editingBase
              ? 'NATIVE_KNOWLEDGE.RENAME'
              : 'NATIVE_KNOWLEDGE.NEW_BASE'
          )
        "
        :confirm-button-label="t('NATIVE_KNOWLEDGE.SAVE')"
        :disable-confirm-button="!name.length || name.length > 200 || busy"
        :is-loading="busy"
        @confirm="saveName"
      >
        <Input v-model="name" :label="t('NATIVE_KNOWLEDGE.NAME')" />
      </Dialog>
      <Dialog
        :key="`history-${route.params.accountId}-${baseId || ''}`"
        ref="historyDialog"
        width="2xl"
        :title="t('NATIVE_KNOWLEDGE.HISTORY')"
        :show-confirm-button="false"
        :cancel-button-label="t('NATIVE_KNOWLEDGE.CLOSE')"
      >
        <div class="max-h-[28rem] space-y-4 overflow-auto">
          <article
            v-for="revision in history"
            :key="revision.id"
            class="rounded-lg border border-n-weak p-3"
          >
            <h3 class="text-sm font-medium">
              {{ t('NATIVE_KNOWLEDGE.VERSION', { version: revision.version }) }}
            </h3>
            <p class="mt-2 whitespace-pre-wrap break-words text-sm">
              {{ revision.question }}
            </p>
            <p
              class="mt-2 whitespace-pre-wrap break-words text-sm text-n-slate-11"
            >
              {{ revision.answer || revision.text }}
            </p>
            <p
              v-if="revision.source_url"
              class="mt-2 break-words text-sm text-n-slate-11"
            >
              {{ revision.source_url }}
            </p>
            <p class="mt-2 text-xs text-n-slate-11">
              {{ t('NATIVE_KNOWLEDGE.PROVENANCE') }}
            </p>
            <pre
              class="mt-2 whitespace-pre-wrap break-words text-xs text-n-slate-11"
              >{{ JSON.stringify(revision.provenance, null, 2) }}</pre
            >
            <Button
              v-if="revision.original_sha256"
              class="mt-2"
              :label="t('NATIVE_KNOWLEDGE.DOWNLOAD_ORIGINAL')"
              variant="ghost"
              @click="exportFile('original', revision.id, revision.filename)"
            />
          </article>
        </div>
      </Dialog>
    </template>
    <p v-else class="text-sm text-n-slate-11">
      {{ t('NATIVE_KNOWLEDGE.UNAVAILABLE') }}
    </p>
  </div>
</template>

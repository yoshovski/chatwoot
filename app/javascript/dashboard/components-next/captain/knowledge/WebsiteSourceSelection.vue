<script setup>
import { computed, onMounted, ref } from 'vue';
import { useTimeoutPoll } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import api from 'dashboard/api/captain/knowledgeSources';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import WebsitePageTree from './WebsitePageTree.vue';
import {
  TABS,
  buildWebsiteTree,
  countByTab,
  recommendedUrls,
} from './websitePageTree';

const props = defineProps({
  assistantId: { type: Number, required: true },
  sourceId: { type: Number, required: true },
});
const emit = defineEmits(['saved', 'cancel']);

const POLL_INTERVAL = 2500;
const { t } = useI18n();
const request = useAbortableRequest();
const previewRequest = useAbortableRequest();
const source = ref(null);
const selected = ref([]);
const initialized = ref(false);
// Recommended pages are pre-checked once, unless the administrator already chose.
const touched = ref(false);
// Recommended until the administrator picks a tab; Other for sources sorted before buckets existed.
const chosenBucket = ref(null);
const search = ref('');
const saving = ref(false);
const error = ref('');
const preview = ref(null);
const autoAddPages = ref(true);

const pages = computed(() => source.value?.pages || []);
const stats = computed(() => source.value?.discovery_stats || {});
const startHost = computed(() =>
  source.value ? new URL(source.value.url).host.replace(/^www\./, '') : ''
);
const counts = computed(() => countByTab(pages.value));
const bucket = computed(
  () =>
    chosenBucket.value || (counts.value.recommended ? 'recommended' : 'other')
);
const tree = computed(() =>
  buildWebsiteTree(pages.value, {
    search: search.value,
    bucket: bucket.value,
    startHost: startHost.value,
  })
);
const discovering = computed(
  () =>
    ['pending', 'discovering'].includes(source.value?.status) &&
    !source.value?.recoverable
);
// Sorting sections and checking unopened pages both run after discovery.
const classifying = computed(
  () =>
    source.value?.status === 'ready' &&
    [stats.value.classification, stats.value.verification].includes('pending')
);
const settled = computed(
  () => source.value?.status === 'ready' && !classifying.value
);
// A round that stopped at a limit starts the next one after its checks finish.
const continuing = computed(
  () => source.value?.status === 'ready' && Boolean(stats.value.continue)
);
// Discovery limits are a server-side cost guard; the picker only says whether it is still working.
const working = computed(
  () => discovering.value || classifying.value || continuing.value
);
const statusText = computed(() => {
  const count = pages.value.length;
  return working.value
    ? t('CAPTAIN.WEBSITES.STILL_FINDING', { count })
    : t('CAPTAIN.WEBSITES.DISCOVERED', { count });
});
const filterTabs = computed(() =>
  TABS.map(tab => ({
    key: tab,
    label: t(`CAPTAIN.WEBSITES.TABS.${tab.toUpperCase()}`),
    count: counts.value[tab],
    help: t(`CAPTAIN.WEBSITES.TAB_HELP.${tab.toUpperCase()}`),
  }))
);
const pageByUrl = computed(
  () => new Map(pages.value.map(page => [page.url, page]))
);
const newDocuments = computed(
  () =>
    selected.value.filter(url => !pageByUrl.value.get(url)?.document_id).length
);
const quotaExceeded = computed(
  () =>
    source.value?.documents_available !== undefined &&
    newDocuments.value > source.value.documents_available
);

let poll;
const precheckRecommended = () => {
  if (touched.value || !settled.value || selected.value.length) return;
  selected.value = recommendedUrls(pages.value);
};

const load = async () => {
  try {
    const response = await request.run(signal =>
      api.source(props.assistantId, props.sourceId, signal)
    );
    if (!response) return;
    source.value = response.data;
    if (!initialized.value) {
      selected.value = [...response.data.selected_urls];
      autoAddPages.value = response.data.auto_add_pages;
      initialized.value = true;
    }
    precheckRecommended();
    if (!working.value) poll.pause();
  } catch {
    error.value = t('CAPTAIN.WEBSITES.LOAD_ERROR');
  }
};
poll = useTimeoutPoll(load, POLL_INTERVAL, { immediate: false });
onMounted(() => {
  load();
  poll.resume();
});

const toggle = ({ urls, selected: include }) => {
  touched.value = true;
  const next = new Set(selected.value);
  urls.forEach(url => (include ? next.add(url) : next.delete(url)));
  selected.value = [...next];
};
const clearSelection = () => {
  touched.value = true;
  selected.value = [];
};
const save = async () => {
  saving.value = true;
  error.value = '';
  try {
    await api.select(
      props.assistantId,
      props.sourceId,
      selected.value,
      autoAddPages.value
    );
    emit('saved');
  } catch (exception) {
    error.value =
      exception.response?.data?.error || t('CAPTAIN.WEBSITES.SAVE_ERROR');
  } finally {
    saving.value = false;
  }
};
const rediscover = async () => {
  error.value = '';
  try {
    const { data } = await api.rediscover(props.assistantId, props.sourceId);
    source.value = data;
    poll.resume();
  } catch {
    error.value = t('CAPTAIN.WEBSITES.LOAD_ERROR');
  }
};
const showPreview = async page => {
  if (!page || page.blocked_reason) return;
  preview.value = { url: page.url };
  try {
    const response = await previewRequest.run(signal =>
      api.preview(props.assistantId, props.sourceId, page.url, signal)
    );
    if (response) preview.value = { ...response.data, url: page.url };
  } catch (exception) {
    preview.value = {
      url: page.url,
      error_code: exception.response?.data?.error_code || 'fetch_failed',
    };
  }
};
</script>

<template>
  <!-- Everything above the footer scrolls, so Save stays visible in a short window. -->
  <div class="flex flex-col gap-3 min-h-0 max-h-[calc(100vh-14rem)]">
    <div class="flex flex-col flex-1 min-h-0 gap-3 overflow-y-auto">
      <div class="flex items-start justify-between gap-3">
        <div class="flex min-w-0 flex-col gap-0.5" role="status">
          <span class="truncate text-sm font-medium text-n-slate-12">
            {{ source?.url }}
          </span>
          <span
            class="inline-flex items-center gap-1.5 text-xs text-n-slate-11"
          >
            <span
              v-if="working"
              class="i-lucide-loader-circle size-3 animate-spin"
              aria-hidden="true"
            />
            {{ statusText }}
          </span>
        </div>
        <Button
          v-if="source && !discovering"
          size="sm"
          variant="ghost"
          color="slate"
          icon="i-lucide-refresh-cw"
          :label="$t('CAPTAIN.WEBSITES.REDISCOVER')"
          @click="rediscover"
        />
      </div>
      <p class="m-0 text-xs text-n-slate-11">
        {{ $t('CAPTAIN.WEBSITES.SELECTION_HELP') }}
      </p>
      <p v-if="stats.auto_added" class="m-0 text-xs text-n-teal-11">
        {{ $t('CAPTAIN.WEBSITES.AUTO_ADDED', { count: stats.auto_added }) }}
      </p>
      <p v-if="source?.status === 'failed'" class="m-0 text-xs text-n-ruby-11">
        {{ $t('CAPTAIN.WEBSITES.DISCOVERY_FAILED') }}
      </p>
      <div class="flex flex-wrap items-center gap-2">
        <div
          class="flex items-center h-8 p-0.5 rounded-lg bg-n-alpha-1 dark:bg-n-solid-1"
          role="tablist"
        >
          <button
            v-for="tab in filterTabs"
            :key="tab.key"
            v-tooltip.top="tab.help"
            type="button"
            role="tab"
            :aria-selected="bucket === tab.key"
            class="h-7 px-3 text-sm rounded-md border-0 transition-colors"
            :class="
              bucket === tab.key
                ? 'bg-n-solid-active text-n-blue-11 shadow-sm outline outline-1 outline-n-container'
                : 'bg-transparent text-n-slate-11 hover:text-n-slate-12'
            "
            @click="chosenBucket = tab.key"
          >
            {{ tab.label }}
            <span class="ms-1 text-xs text-n-slate-10">{{ tab.count }}</span>
          </button>
        </div>
        <Input
          v-model="search"
          type="search"
          class="flex-1 min-w-48"
          :placeholder="$t('CAPTAIN.WEBSITES.SEARCH')"
        />
      </div>
      <div class="grid gap-3 md:grid-cols-5">
        <div
          class="flex flex-col h-80 overflow-hidden rounded-lg border border-n-weak md:col-span-3"
        >
          <div
            class="flex items-center gap-2 px-3 py-2 text-xs border-b border-n-weak text-n-slate-11"
          >
            <span class="text-n-slate-12">
              {{
                $t('CAPTAIN.WEBSITES.SELECTED_OF', {
                  selected: selected.length,
                  total: pages.length,
                })
              }}
            </span>
            <span class="rounded-full size-1 bg-n-slate-8" aria-hidden="true" />
            <button
              type="button"
              class="p-0 text-xs bg-transparent border-0 text-n-slate-11 hover:text-n-slate-12 hover:underline disabled:opacity-50 disabled:no-underline"
              :disabled="!selected.length"
              @click="clearSelection"
            >
              {{ $t('CAPTAIN.WEBSITES.CLEAR_SELECTION') }}
            </button>
            <span
              v-if="source?.hidden_pages"
              v-tooltip.top="
                $t('CAPTAIN.WEBSITES.HIDDEN_PAGES', {
                  count: source.hidden_pages,
                })
              "
              class="ms-auto text-n-slate-10"
            >
              {{
                $t('CAPTAIN.WEBSITES.HIDDEN_COUNT', {
                  count: source.hidden_pages,
                })
              }}
            </span>
          </div>
          <div class="flex-1 min-h-0 p-2 overflow-auto">
            <WebsitePageTree
              v-for="node in tree"
              :key="node.key"
              :node="node"
              :selected="selected"
              :section-labels="stats.sections || {}"
              @toggle="toggle"
              @preview="showPreview"
            />
            <p v-if="!tree.length" class="m-0 p-1 text-sm text-n-slate-11">
              {{ $t('CAPTAIN.WEBSITES.NO_PAGES') }}
            </p>
          </div>
        </div>
        <div
          class="h-80 p-3 overflow-auto rounded-lg md:col-span-2 bg-n-alpha-1"
        >
          <template v-if="preview">
            <p class="m-0 mb-2 break-all text-xs text-n-slate-11">
              {{ preview.url }}
            </p>
            <p
              v-if="previewRequest.isPending.value"
              class="m-0 text-sm text-n-slate-11"
            >
              {{ $t('CAPTAIN.WEBSITES.PREVIEW_LOADING') }}
            </p>
            <p
              v-else-if="preview.error_code"
              class="m-0 text-sm text-n-slate-11"
            >
              {{
                $t('CAPTAIN.WEBSITES.PREVIEW_UNAVAILABLE', {
                  reason: $t(
                    `CAPTAIN.DOCUMENTS.SYNC_ERRORS.${preview.error_code.toUpperCase()}`
                  ),
                })
              }}
            </p>
            <template v-else>
              <p
                v-if="preview.skip_reason"
                class="m-0 mb-2 text-xs text-n-amber-11"
              >
                {{ $t('CAPTAIN.WEBSITES.PREVIEW_THIN') }}
              </p>
              <p
                v-else-if="preview.words !== undefined"
                class="m-0 mb-2 text-xs text-n-slate-10"
              >
                {{
                  $t('CAPTAIN.WEBSITES.PREVIEW_WORDS', { count: preview.words })
                }}
              </p>
              <div
                class="whitespace-pre-wrap break-words font-sans text-sm text-n-slate-12"
              >
                {{ preview.content }}
              </div>
            </template>
          </template>
          <div
            v-else
            class="flex flex-col items-center justify-center h-full gap-2 text-center"
          >
            <span class="i-lucide-file-text size-5 text-n-slate-9" />
            <p class="m-0 text-xs text-n-slate-11">
              {{ $t('CAPTAIN.WEBSITES.PREVIEW_HELP') }}
            </p>
          </div>
        </div>
      </div>
    </div>
    <p v-if="error" role="alert" class="m-0 text-sm text-n-ruby-11">
      {{ error }}
    </p>
    <p v-if="quotaExceeded" role="alert" class="m-0 text-sm text-n-ruby-11">
      {{
        $t('CAPTAIN.WEBSITES.QUOTA_EXCEEDED', {
          count: newDocuments,
          available: source.documents_available,
        })
      }}
    </p>
    <div
      class="flex flex-wrap items-center justify-between gap-3 pt-3 border-t shrink-0 border-n-weak"
    >
      <label
        v-tooltip.top="$t('CAPTAIN.WEBSITES.AUTO_ADD_HINT')"
        class="flex items-center gap-2 text-sm cursor-pointer text-n-slate-12"
      >
        <Switch
          v-model="autoAddPages"
          :aria-label="$t('CAPTAIN.WEBSITES.AUTO_ADD')"
        />
        {{ $t('CAPTAIN.WEBSITES.AUTO_ADD') }}
      </label>
      <span
        v-tooltip.top="
          discovering ? $t('CAPTAIN.WEBSITES.SAVE_DURING_DISCOVERY') : ''
        "
        class="ms-auto text-sm text-n-slate-11"
      >
        {{
          $t('CAPTAIN.WEBSITES.SELECTION_SUMMARY', {
            selected: selected.length,
            new: newDocuments,
          })
        }}
      </span>
      <div class="flex items-center gap-2">
        <Button
          variant="faded"
          color="slate"
          :label="$t('CAPTAIN.FORM.CANCEL')"
          @click="emit('cancel')"
        />
        <Button
          :label="$t('CAPTAIN.WEBSITES.SAVE_SELECTION')"
          :disabled="!source || saving || quotaExceeded"
          :is-loading="saving"
          @click="save"
        />
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue';
import { useTimeoutPoll } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import api from 'dashboard/api/captain/knowledgeSources';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import WebsitePageTree from './WebsitePageTree.vue';
import {
  BUCKETS,
  buildWebsiteTree,
  countByBucket,
  recommendedUrls,
} from './websitePageTree';

const props = defineProps({
  assistantId: { type: Number, required: true },
  sourceId: { type: Number, required: true },
});
const emit = defineEmits(['saved', 'cancel']);

const POLL_INTERVAL = 2500;
const MAX_PAGE_CHECKS = 500;
const FILTERS = [...BUCKETS, 'all'];
const { t } = useI18n();
const request = useAbortableRequest();
const previewRequest = useAbortableRequest();
const source = ref(null);
const selected = ref([]);
const initialized = ref(false);
// Recommended pages are pre-checked once, unless the administrator already chose.
const touched = ref(false);
// Recommended until the administrator picks a tab; All for sources sorted before buckets existed.
const chosenBucket = ref(null);
const search = ref('');
const saving = ref(false);
const error = ref('');
const preview = ref(null);

const pages = computed(() => source.value?.pages || []);
const stats = computed(() => source.value?.discovery_stats || {});
const startHost = computed(() =>
  source.value ? new URL(source.value.url).host.replace(/^www\./, '') : ''
);
const counts = computed(() => countByBucket(pages.value));
const bucket = computed(
  () => chosenBucket.value || (counts.value.recommended ? 'recommended' : 'all')
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
const statusText = computed(() => {
  const count = pages.value.length;
  if (classifying.value) return t('CAPTAIN.WEBSITES.CLASSIFYING', { count });
  if (!discovering.value) return t('CAPTAIN.WEBSITES.DISCOVERED', { count });
  return t('CAPTAIN.WEBSITES.DISCOVERING', { count });
});
const phaseText = computed(() => {
  if (!discovering.value || !stats.value.phase) return '';
  return t(`CAPTAIN.WEBSITES.PHASE.${stats.value.phase.toUpperCase()}`, {
    count: stats.value.fetched_pages || 0,
    max: MAX_PAGE_CHECKS,
  });
});
const limitsText = computed(() =>
  (stats.value.limits || [])
    .map(limit => t(`CAPTAIN.WEBSITES.LIMITS.${limit}`))
    .join(', ')
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
      initialized.value = true;
    }
    precheckRecommended();
    if (!discovering.value && !classifying.value) poll.pause();
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
const selectRecommended = () =>
  toggle({ urls: recommendedUrls(pages.value), selected: true });
const clearSelection = () => {
  touched.value = true;
  selected.value = [];
};
const save = async () => {
  saving.value = true;
  error.value = '';
  try {
    await api.select(props.assistantId, props.sourceId, selected.value);
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
  <div class="flex flex-col gap-4">
    <p class="m-0 break-all text-sm text-n-slate-11">{{ source?.url }}</p>
    <p class="m-0 text-sm text-n-slate-11">
      {{ $t('CAPTAIN.WEBSITES.SELECTION_HELP') }}
    </p>
    <div class="flex items-center justify-between gap-3">
      <div class="flex min-w-0 flex-col" role="status">
        <span class="text-sm text-n-slate-12">{{ statusText }}</span>
        <span v-if="phaseText" class="text-xs text-n-slate-11">
          {{ phaseText }}
        </span>
      </div>
      <Button
        v-if="source && !discovering"
        size="sm"
        variant="faded"
        :label="$t('CAPTAIN.WEBSITES.REDISCOVER')"
        @click="rediscover"
      />
    </div>
    <p v-if="limitsText" class="m-0 text-sm text-n-amber-11">
      {{ $t('CAPTAIN.WEBSITES.LIMITED', { limits: limitsText }) }}
    </p>
    <p
      v-if="stats.classification === 'failed'"
      class="m-0 text-sm text-n-slate-11"
    >
      {{ $t('CAPTAIN.WEBSITES.CLASSIFICATION_FAILED') }}
    </p>
    <p v-if="source?.status === 'failed'" class="m-0 text-sm text-n-ruby-11">
      {{ $t('CAPTAIN.WEBSITES.DISCOVERY_FAILED') }}
    </p>
    <div class="flex flex-wrap items-center gap-2">
      <Button
        v-for="filter in FILTERS"
        :key="filter"
        size="sm"
        :variant="bucket === filter ? 'solid' : 'faded'"
        :color="bucket === filter ? 'blue' : 'slate'"
        :label="
          $t(`CAPTAIN.WEBSITES.BUCKETS.${filter.toUpperCase()}`, {
            count: counts[filter],
          })
        "
        @click="chosenBucket = filter"
      />
    </div>
    <p class="m-0 text-xs text-n-slate-11">
      {{ $t(`CAPTAIN.WEBSITES.BUCKET_HELP.${bucket.toUpperCase()}`) }}
    </p>
    <p v-if="source?.hidden_pages" class="m-0 text-xs text-n-slate-10">
      {{ $t('CAPTAIN.WEBSITES.HIDDEN_PAGES', { count: source.hidden_pages }) }}
    </p>
    <Input
      v-model="search"
      type="search"
      :placeholder="$t('CAPTAIN.WEBSITES.SEARCH')"
    />
    <div class="flex flex-wrap items-center gap-2">
      <Button
        size="sm"
        variant="faded"
        :label="$t('CAPTAIN.WEBSITES.SELECT_RECOMMENDED')"
        :disabled="!counts.recommended"
        @click="selectRecommended"
      />
      <Button
        size="sm"
        variant="ghost"
        color="slate"
        :label="$t('CAPTAIN.WEBSITES.CLEAR_SELECTION')"
        :disabled="!selected.length"
        @click="clearSelection"
      />
    </div>
    <div class="grid gap-4 md:grid-cols-2">
      <div class="max-h-96 overflow-auto rounded-lg border border-n-weak p-3">
        <WebsitePageTree
          v-for="node in tree"
          :key="node.key"
          :node="node"
          :selected="selected"
          :section-labels="stats.sections || {}"
          @toggle="toggle"
          @preview="showPreview"
        />
        <p v-if="!tree.length" class="text-sm text-n-slate-11">
          {{ $t('CAPTAIN.WEBSITES.NO_PAGES') }}
        </p>
      </div>
      <div class="max-h-96 overflow-auto rounded-lg border border-n-weak p-3">
        <template v-if="preview">
          <p class="break-all text-xs text-n-slate-11">{{ preview.url }}</p>
          <p
            v-if="previewRequest.isPending.value"
            class="text-sm text-n-slate-11"
          >
            {{ $t('CAPTAIN.WEBSITES.PREVIEW_LOADING') }}
          </p>
          <p v-else-if="preview.error_code" class="text-sm text-n-ruby-11">
            {{
              $t(
                `CAPTAIN.DOCUMENTS.SYNC_ERRORS.${preview.error_code.toUpperCase()}`
              )
            }}
          </p>
          <template v-else>
            <p v-if="preview.skip_reason" class="mb-2 text-sm text-n-amber-11">
              {{ $t('CAPTAIN.WEBSITES.PREVIEW_THIN') }}
            </p>
            <p
              v-else-if="preview.words !== undefined"
              class="mb-2 text-xs text-n-slate-11"
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
        <p v-else class="text-sm text-n-slate-11">
          {{ $t('CAPTAIN.WEBSITES.PREVIEW_HELP') }}
        </p>
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
    <div class="flex items-center justify-between gap-3">
      <Button
        variant="faded"
        color="slate"
        :label="$t('CAPTAIN.FORM.CANCEL')"
        @click="emit('cancel')"
      />
      <div class="flex min-w-0 items-center gap-3">
        <span class="text-xs text-n-slate-11">
          {{
            discovering
              ? $t('CAPTAIN.WEBSITES.SAVE_DURING_DISCOVERY')
              : $t('CAPTAIN.WEBSITES.NEW_DOCUMENTS', { count: newDocuments })
          }}
        </span>
        <Button
          :label="
            $t('CAPTAIN.WEBSITES.SAVE_SELECTION', { count: selected.length })
          "
          :disabled="!source || saving || quotaExceeded"
          :is-loading="saving"
          @click="save"
        />
      </div>
    </div>
  </div>
</template>

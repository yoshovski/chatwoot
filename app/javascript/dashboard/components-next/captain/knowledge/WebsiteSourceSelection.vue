<script setup>
import { computed, onMounted, ref } from 'vue';
import { useTimeoutPoll } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import api from 'dashboard/api/captain/knowledgeSources';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import WebsitePageTree from './WebsitePageTree.vue';
import { buildWebsiteTree } from './websitePageTree';

const props = defineProps({
  assistantId: { type: Number, required: true },
  sourceId: { type: Number, required: true },
});
const emit = defineEmits(['saved', 'cancel']);
const { t } = useI18n();
const request = useAbortableRequest();
const previewRequest = useAbortableRequest();
const source = ref(null);
const selected = ref([]);
const initialized = ref(false);
const search = ref('');
const saving = ref(false);
const error = ref('');
const preview = ref(null);
const tree = computed(() =>
  buildWebsiteTree(source.value?.pages || [], search.value)
);
const discovering = computed(
  () =>
    ['pending', 'discovering'].includes(source.value?.status) &&
    !source.value?.recoverable
);
let poll;

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
    if (!discovering.value) poll.pause();
  } catch {
    error.value = t('CAPTAIN.WEBSITES.LOAD_ERROR');
  }
};
poll = useTimeoutPoll(load, 2500, { immediate: false });
onMounted(() => {
  load();
  poll.resume();
});

const toggle = ({ urls, selected: include }) => {
  const next = new Set(selected.value);
  urls.forEach(url => (include ? next.add(url) : next.delete(url)));
  selected.value = [...next];
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
      <span class="text-sm text-n-slate-12" role="status">
        {{
          $t(
            discovering
              ? 'CAPTAIN.WEBSITES.DISCOVERING'
              : 'CAPTAIN.WEBSITES.DISCOVERED',
            { count: source?.pages.length || 0 }
          )
        }}
      </span>
      <Button
        v-if="source && !discovering"
        size="sm"
        variant="faded"
        :label="$t('CAPTAIN.WEBSITES.REDISCOVER')"
        @click="rediscover"
      />
    </div>
    <p
      v-if="source?.discovery_stats.limited"
      class="m-0 text-sm text-n-amber-11"
    >
      {{ $t('CAPTAIN.WEBSITES.LIMITED') }}
    </p>
    <p v-if="source?.status === 'failed'" class="m-0 text-sm text-n-ruby-11">
      {{ $t('CAPTAIN.WEBSITES.DISCOVERY_FAILED') }}
    </p>
    <Input
      v-model="search"
      type="search"
      :placeholder="$t('CAPTAIN.WEBSITES.SEARCH')"
    />
    <div class="grid gap-4 md:grid-cols-2">
      <div class="max-h-96 overflow-auto rounded-lg border border-n-weak p-3">
        <WebsitePageTree
          v-for="node in tree"
          :key="node.key"
          :node="node"
          :selected="selected"
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
          <div
            v-else
            class="whitespace-pre-wrap break-words font-sans text-sm text-n-slate-12"
          >
            {{ preview.content }}
          </div>
        </template>
        <p v-else class="text-sm text-n-slate-11">
          {{ $t('CAPTAIN.WEBSITES.PREVIEW_HELP') }}
        </p>
      </div>
    </div>
    <p v-if="error" role="alert" class="m-0 text-sm text-n-ruby-11">
      {{ error }}
    </p>
    <div class="flex items-center justify-between gap-3">
      <Button
        variant="faded"
        color="slate"
        :label="$t('CAPTAIN.FORM.CANCEL')"
        @click="emit('cancel')"
      />
      <Button
        :label="
          $t('CAPTAIN.WEBSITES.SAVE_SELECTION', { count: selected.length })
        "
        :disabled="source?.status !== 'ready' || saving"
        :is-loading="saving"
        @click="save"
      />
    </div>
  </div>
</template>

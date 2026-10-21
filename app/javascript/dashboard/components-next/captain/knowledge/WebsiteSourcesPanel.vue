<script setup>
import { computed, nextTick, ref, watch } from 'vue';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import api from 'dashboard/api/captain/knowledgeSources';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import WebsiteSourceSelection from './WebsiteSourceSelection.vue';

const props = defineProps({
  assistantId: { type: Number, required: true },
  activeWebsite: { type: String, default: null },
});
const emit = defineEmits(['saved']);
const sources = ref([]);

const sourceHost = url => {
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return '';
  }
};

const isSourceForActiveWebsite = (source, active) => {
  if (!active || active === '*') return true;
  const host = sourceHost(source.url);
  if (!host) return false;
  if (host === active) return true;
  if (active.endsWith(`.${host}`)) return true;
  if (host.endsWith(`.${active}`)) return true;
  return (source.selected_urls || []).some(url => sourceHost(url) === active);
};

const visibleSources = computed(() =>
  sources.value.filter(source =>
    isSourceForActiveWebsite(source, props.activeWebsite)
  )
);

const getSourceSubtext = source => {
  const rootHost = sourceHost(source.url);
  const total = source.selected_urls?.length || 0;
  if (
    props.activeWebsite &&
    props.activeWebsite !== rootHost &&
    props.activeWebsite !== '*'
  ) {
    const subdomainCount = (source.selected_urls || []).filter(
      url => sourceHost(url) === props.activeWebsite
    ).length;
    return `Discovered via ${rootHost} · ${subdomainCount} pages on ${props.activeWebsite} (${total} total selected)`;
  }
  return `${total} pages selected for knowledge ingestion`;
};

const selectedSource = ref(null);
const dialog = ref(null);
const request = useAbortableRequest();
const load = async () => {
  try {
    const response = await request.run(signal =>
      api.list(props.assistantId, signal)
    );
    if (response) sources.value = response.data;
  } catch {
    sources.value = [];
  }
};
const open = async source => {
  selectedSource.value = source;
  await nextTick();
  dialog.value.open();
};
const saved = () => {
  dialog.value.close();
  load();
  emit('saved');
};
watch(() => props.assistantId, load, { immediate: true });
defineExpose({ load });
</script>

<template>
  <section
    v-if="visibleSources.length"
    class="mb-4 rounded-xl border border-n-weak bg-n-solid-1 p-4 shadow-sm"
  >
    <div class="mb-3 flex items-start justify-between gap-2">
      <div>
        <h3 class="m-0 text-sm font-semibold text-n-slate-12">
          {{ $t('CAPTAIN.WEBSITES.INGESTION_TITLE') }}
        </h3>
        <p class="m-0 mt-0.5 text-xs text-n-slate-11">
          {{ $t('CAPTAIN.WEBSITES.INGESTION_SUBTITLE') }}
        </p>
      </div>
    </div>
    <div
      v-for="source in visibleSources"
      :key="source.id"
      class="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-n-weak/60 bg-n-background px-3 py-2.5"
    >
      <div class="min-w-0">
        <p class="m-0 truncate text-sm font-medium text-n-slate-12">
          {{ source.url }}
        </p>
        <span class="text-xs text-n-slate-11">
          {{ getSourceSubtext(source) }}
        </span>
      </div>
      <Button
        size="sm"
        variant="faded"
        icon="i-lucide-layers"
        :label="$t('CAPTAIN.WEBSITES.MANAGE_INGESTED')"
        @click="open(source)"
      />
    </div>
  </section>
  <Dialog
    v-if="selectedSource"
    ref="dialog"
    width="3xl"
    :title="$t('CAPTAIN.WEBSITES.TITLE')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="selectedSource = null"
  >
    <WebsiteSourceSelection
      :key="selectedSource.id"
      :assistant-id="assistantId"
      :source-id="selectedSource.id"
      @saved="saved"
      @cancel="dialog.close()"
    />
    <template #footer />
  </Dialog>
</template>

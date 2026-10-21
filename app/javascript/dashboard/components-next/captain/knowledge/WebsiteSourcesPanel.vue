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
const visibleSources = computed(() =>
  sources.value.filter(
    source =>
      !props.activeWebsite ||
      new URL(source.url).hostname.replace(/^www\./, '') === props.activeWebsite
  )
);
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
    class="mb-4 rounded-xl border border-n-weak p-4"
  >
    <h3 class="mb-3 text-sm font-medium text-n-slate-12">
      {{ $t('CAPTAIN.WEBSITES.TITLE') }}
    </h3>
    <div
      v-for="source in visibleSources"
      :key="source.id"
      class="flex items-center justify-between gap-3 py-2"
    >
      <div class="min-w-0">
        <p class="m-0 truncate text-sm text-n-slate-12">{{ source.url }}</p>
        <span class="text-xs text-n-slate-11">
          {{
            $t('CAPTAIN.WEBSITES.SELECTED_COUNT', {
              count: source.selected_urls.length,
            })
          }}
        </span>
      </div>
      <Button
        size="sm"
        variant="faded"
        :label="$t('CAPTAIN.WEBSITES.MANAGE')"
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

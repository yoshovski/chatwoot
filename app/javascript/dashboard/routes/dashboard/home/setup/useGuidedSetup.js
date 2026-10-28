import { computed, ref } from 'vue';
import { useTimeoutPoll } from '@vueuse/core';
import GuidedSetupAPI from 'dashboard/api/captain/guidedSetup';
import CaptainHomeAPI from 'dashboard/api/captain/home';
import KnowledgeSourcesAPI from 'dashboard/api/captain/knowledgeSources';
import { importProgress, pagesToImport } from './importProgress';

const POLL_INTERVAL = 3000;
const errorMessage = error => error?.response?.data?.error || '';

// State and actions for the guided setup. Progress comes from the Home summary (the checklist's data source); the
// website import is followed by polling its website source until every chosen page is read.
export function useGuidedSetup() {
  const state = ref(null);
  const setup = ref(null);
  const source = ref(null);
  const isLoading = ref(true);
  const loadError = ref(false);
  const importError = ref('');
  const isSelecting = ref(false);

  const assistantId = computed(() => state.value?.assistant_id);
  const progress = computed(() => importProgress(source.value));
  const isImporting = computed(() =>
    ['finding', 'select', 'reading'].includes(progress.value.phase)
  );

  const loadSummary = async () => {
    const { data } = await CaptainHomeAPI.get();
    setup.value = data.setup;
  };

  // Imports the recommended pages once discovery settles, so the owner doesn't have to pick them here.
  const importRecommended = async () => {
    if (isSelecting.value) return;
    const urls = pagesToImport(
      progress.value,
      source.value.documents_available
    );
    if (!urls.length) return;
    isSelecting.value = true;
    try {
      const { data } = await KnowledgeSourcesAPI.select(
        assistantId.value,
        source.value.id,
        urls,
        true
      );
      source.value = data;
      // Imported pages count as knowledge on the checklist right away.
      await loadSummary();
    } catch (error) {
      importError.value = errorMessage(error) || 'IMPORT_FAILED';
    } finally {
      isSelecting.value = false;
    }
  };

  const loadSource = async () => {
    const sourceId = state.value?.website_source?.id;
    if (!sourceId || !assistantId.value) return;
    const { data } = await KnowledgeSourcesAPI.source(
      assistantId.value,
      sourceId
    );
    source.value = data;
    if (progress.value.phase === 'select' && !importError.value) {
      await importRecommended();
    }
  };

  const poll = useTimeoutPoll(
    async () => {
      try {
        await loadSource();
      } catch {
        // A missed poll is retried on the next tick.
      }
      if (!isImporting.value) poll.pause();
    },
    POLL_INTERVAL,
    { immediate: false }
  );

  const followImport = () => {
    if (isImporting.value) poll.resume();
  };

  const load = async () => {
    isLoading.value = true;
    loadError.value = false;
    try {
      const [{ data }] = await Promise.all([
        GuidedSetupAPI.get(),
        loadSummary(),
      ]);
      state.value = data;
      await loadSource();
      followImport();
    } catch {
      loadError.value = true;
    } finally {
      isLoading.value = false;
    }
  };

  const startWebsite = async url => {
    importError.value = '';
    try {
      const { data } = await GuidedSetupAPI.startWebsite(url);
      state.value = data;
      await loadSource();
      followImport();
      return { ok: true };
    } catch (error) {
      return { ok: false, error: errorMessage(error) };
    }
  };

  const retryImport = async () => {
    importError.value = '';
    try {
      const { data } = await KnowledgeSourcesAPI.rediscover(
        assistantId.value,
        source.value.id
      );
      source.value = data;
      followImport();
    } catch (error) {
      importError.value = errorMessage(error) || 'IMPORT_FAILED';
    }
  };

  const goLive = async () => {
    try {
      const { data } = await GuidedSetupAPI.goLive();
      state.value = data;
      await loadSummary();
      return { ok: true };
    } catch (error) {
      return { ok: false, error: errorMessage(error) };
    }
  };

  const checkInstallation = async () => {
    const { data } = await GuidedSetupAPI.checkInstallation();
    if (data.status === 'installed') await loadSummary();
    return data.status;
  };

  return {
    state,
    setup,
    source,
    progress,
    isLoading,
    loadError,
    importError,
    isImporting,
    assistantId,
    load,
    startWebsite,
    retryImport,
    goLive,
    checkInstallation,
    stopPolling: () => poll.pause(),
  };
}

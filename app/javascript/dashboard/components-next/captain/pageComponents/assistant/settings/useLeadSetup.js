import { computed, ref, watch } from 'vue';
import ScenariosAPI from 'dashboard/api/captain/scenarios';
import IntegrationsAPI from 'dashboard/api/integrations';

// Read saved setup, independently of the draft being edited on this page.
export function useLeadSetup(assistantId) {
  const scenarios = ref([]);
  const hubspot = ref(null);
  const loading = ref(true);
  const scenarioError = ref(false);
  const integrationError = ref(false);
  const refreshKey = ref(0);

  watch(
    [assistantId, refreshKey],
    async ([id], _, onCleanup) => {
      if (!id) return;
      let active = true;
      onCleanup(() => {
        active = false;
      });
      loading.value = true;
      const results = await Promise.allSettled([
        ScenariosAPI.get({ assistantId: id }),
        IntegrationsAPI.get(),
      ]);
      if (!active) return;
      const [scenarioResult, integrationResult] = results;
      scenarioError.value = scenarioResult.status === 'rejected';
      integrationError.value = integrationResult.status === 'rejected';
      scenarios.value = scenarioError.value
        ? []
        : scenarioResult.value.data.payload;
      hubspot.value = integrationError.value
        ? null
        : integrationResult.value.data.payload.find(app => app.id === 'hubspot')
            ?.hooks?.[0] || null;
      loading.value = false;
    },
    { immediate: true }
  );

  const captureScenario = computed(() =>
    scenarios.value.find(
      scenario =>
        scenario.enabled && scenario.tools?.includes('save_lead_details')
    )
  );
  const hubspotState = computed(() => {
    if (loading.value) return 'loading';
    if (integrationError.value) return 'unavailable';
    if (!hubspot.value) return 'not_connected';
    if (
      hubspot.value.status !== true ||
      hubspot.value.settings?.reauthorization_required
    )
      return 'reconnect';
    if (!hubspot.value.settings) return 'unavailable';
    if (!hubspot.value.settings.sync_contacts) return 'sync_off';
    const mapping = hubspot.value.settings?.field_mapping || {};
    return mapping.lead_type && mapping.lead_summary && mapping.lead_source
      ? 'mapped'
      : 'mapping_needed';
  });

  return {
    captureScenario,
    hubspotState,
    loading,
    scenarioError,
    refresh: () => {
      refreshKey.value += 1;
    },
  };
}

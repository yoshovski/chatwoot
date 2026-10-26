import { computed, ref, watch } from 'vue';
import ScenariosAPI from 'dashboard/api/captain/scenarios';
import IntegrationsAPI from 'dashboard/api/integrations';

// Read saved setup, independently of the draft being edited on this page.
export function useLeadSetup(assistantId, leadFields) {
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

  const leadScenarios = computed(() =>
    scenarios.value.filter(scenario =>
      scenario.tools?.includes('save_lead_details')
    )
  );
  const captureScenario = computed(() =>
    leadScenarios.value.find(scenario => scenario.enabled)
  );
  const existingScenario = computed(
    () => captureScenario.value || leadScenarios.value[0]
  );
  const hubspotConnectionState = computed(() => {
    if (loading.value) return 'loading';
    if (integrationError.value) return 'unavailable';
    if (!hubspot.value) return 'not_connected';
    if (
      hubspot.value.status !== true ||
      hubspot.value.settings?.reauthorization_required
    )
      return 'reconnect';
    if (!hubspot.value.settings) return 'unavailable';
    return 'connected';
  });
  const requiredMappingKeys = computed(() => [
    'email',
    'lead_type',
    'lead_summary',
    'lead_source',
    ...(leadFields?.value || [])
      .filter(field => field.key)
      .map(field => `lead_${field.key}`),
  ]);
  const unmappedKeys = computed(() => {
    if (hubspotConnectionState.value !== 'connected') return [];
    const mapping = hubspot.value.settings?.field_mapping || {};
    return requiredMappingKeys.value.filter(key => !mapping[key]);
  });
  const hubspotState = computed(() => {
    if (hubspotConnectionState.value !== 'connected')
      return hubspotConnectionState.value;
    if (!hubspot.value.settings.sync_contacts) return 'sync_off';
    return unmappedKeys.value.length === 0 ? 'mapped' : 'mapping_needed';
  });
  const transcriptState = computed(() => {
    if (hubspotConnectionState.value !== 'connected')
      return hubspotConnectionState.value;
    return hubspot.value.settings.save_transcripts ? 'on' : 'off';
  });

  return {
    captureScenario,
    existingScenario,
    hubspotState,
    transcriptState,
    requiredMappingKeys,
    unmappedKeys,
    businessLeadsOnly: computed(
      () => hubspot.value?.settings?.contact_sync_scope === 'business_leads'
    ),
    loading,
    scenarioError,
    refresh: () => {
      refreshKey.value += 1;
    },
  };
}

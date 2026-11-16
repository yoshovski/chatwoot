/* eslint-disable @intlify/vue-i18n/no-dynamic-keys -- Keys share a fixed namespace and come from the lead settings or status list. */
import {
  computed,
  inject,
  nextTick,
  onMounted,
  provide,
  ref,
  toRaw,
  watch,
} from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import TeamsAPI from 'dashboard/api/teams';
import { useLeadSetup } from '../useLeadSetup';

// The lead setup draft shared by the three steps (What to ask · When to ask · Where it goes).
// The saved data is the assistant config, unchanged: the steps only split where it is edited.
export const MAX_ENTRIES = 10;
export const MAX_TEXT_LENGTH = 300;
export const KEY_PATTERN = /^[a-z][a-z0-9_]{0,39}$/;
export const RESERVED_KEYS = [
  'type',
  'summary',
  'source',
  'status',
  'visitor_city',
  'visitor_country',
  'visitor_country_code',
];
export const COMMON_FIELDS = [
  'use_case',
  'audience_size',
  'company',
  'country',
];
export const STEPS = ['ask', 'when', 'where'];

const KEY = Symbol('leadSettings');

// `assistant` and `canManageIntegrations` are refs; `save` stores the config.
export function createLeadSettings({
  assistant,
  save: saveConfig,
  canManageIntegrations,
}) {
  const { t } = useI18n();
  const router = useRouter();
  const store = useStore();

  const label = (key, params = {}) =>
    t(`CAPTAIN.ASSISTANTS.SETTINGS.LEADS.${key}`, params);

  const settings = ref({});
  const savedSnapshot = ref('');
  const saving = ref(false);
  const attempted = ref(false);
  const activating = ref(false);
  const scenarioDialog = ref(null);

  const setup = useLeadSetup(
    computed(() => assistant.value.id),
    computed(() => settings.value.lead_fields)
  );
  const { captureScenario, existingScenario, hubspotState, loading } = setup;

  const guidedSetup = computed(
    () => settings.value.lead_guided_setup ?? !existingScenario.value
  );

  const teams = ref([]);
  const teamsError = ref(false);
  onMounted(async () => {
    store.dispatch('attributes/get');
    try {
      const { data } = await TeamsAPI.get();
      teams.value = data;
    } catch {
      teamsError.value = true;
    }
  });

  const snapshot = () => JSON.stringify(settings.value);
  const isDirty = computed(
    () =>
      snapshot() !== savedSnapshot.value ||
      (settings.value.leads_enabled &&
        settings.value.lead_guided_setup === null &&
        !loading.value &&
        !setup.scenarioError.value &&
        !existingScenario.value)
  );

  let lockedFields = new WeakSet();
  const fieldKeyLocked = field => lockedFields.has(toRaw(field));

  const reset = () => {
    const config = assistant.value.config || {};
    settings.value = {
      leads_enabled: config.leads_enabled === true,
      lead_guided_setup: config.lead_guided_setup ?? null,
      lead_trigger: config.lead_trigger ?? label('GUIDED.DEFAULT_TRIGGER'),
      lead_instructions: config.lead_instructions ?? '',
      lead_max_questions: config.lead_max_questions ?? 2,
      lead_handoff_capture_enabled:
        config.lead_handoff_capture_enabled === true,
      lead_notification_team_id: config.lead_notification_team_id ?? null,
      published_pricing_enabled: config.published_pricing_enabled === true,
      lead_fields: (config.lead_fields || []).map(field => ({ ...field })),
      lead_types: (config.lead_types || []).map(type => ({ ...type })),
    };
    lockedFields = new WeakSet(settings.value.lead_fields.map(toRaw));
    savedSnapshot.value = snapshot();
    attempted.value = false;
    activating.value = false;
  };

  watch(
    () => assistant.value.config,
    () => {
      if (!isDirty.value || saving.value || !savedSnapshot.value) reset();
    },
    { immediate: true }
  );

  const fieldErrorFor = (field, ignoreIndex = -1) => {
    if (!KEY_PATTERN.test(field.key) || RESERVED_KEYS.includes(field.key))
      return label('ERRORS.KEY');
    if (
      settings.value.lead_fields.some(
        (item, idx) => idx !== ignoreIndex && item.key === field.key
      )
    )
      return label('ERRORS.DUPLICATE_KEY');
    if (!field.label.trim() || field.label.length > MAX_TEXT_LENGTH)
      return label('ERRORS.FIELD');
    return '';
  };
  const fieldError = field =>
    fieldErrorFor(field, settings.value.lead_fields.indexOf(field));

  const typeErrorFor = (type, ignoreIndex = -1) => {
    if (
      !type.name.trim() ||
      !type.rule.trim() ||
      type.name.length > MAX_TEXT_LENGTH ||
      type.rule.length > MAX_TEXT_LENGTH
    )
      return label('ERRORS.TYPE');
    if (
      settings.value.lead_types.some(
        (item, idx) =>
          idx !== ignoreIndex && item.name.trim() === type.name.trim()
      )
    )
      return label('ERRORS.DUPLICATE_TYPE');
    return '';
  };
  const typeError = type =>
    typeErrorFor(type, settings.value.lead_types.indexOf(type));

  const isFieldSelected = key =>
    settings.value.lead_fields.some(field => field.key === key);

  const togglePresetField = (key, displayLabel) => {
    const index = settings.value.lead_fields.findIndex(
      field => field.key === key
    );
    if (index >= 0) {
      settings.value.lead_fields.splice(index, 1);
      return;
    }
    if (settings.value.lead_fields.length >= MAX_ENTRIES) return;
    settings.value.lead_fields.push({ key, label: displayLabel });
  };

  // Every error lives in "What to ask": fields and lead types.
  const hasErrors = computed(
    () =>
      ((settings.value.leads_enabled || activating.value) &&
        !settings.value.lead_types.length) ||
      settings.value.lead_fields.some(fieldError) ||
      settings.value.lead_types.some(typeError)
  );

  const save = async (formElement, enabled = settings.value.leads_enabled) => {
    if (saving.value || loading.value || setup.scenarioError.value)
      return false;
    activating.value = enabled;
    attempted.value = true;
    if (hasErrors.value) {
      await nextTick();
      formElement?.querySelector('[aria-invalid="true"]')?.focus();
      return false;
    }
    saving.value = true;
    try {
      const config = {
        ...JSON.parse(snapshot()),
        leads_enabled: enabled,
        lead_guided_setup: guidedSetup.value,
      };
      const result = await saveConfig({ config });
      if (result === false) return false;
      store.dispatch('attributes/get');
      setup.refresh();
      settings.value = config;
      lockedFields = new WeakSet(settings.value.lead_fields.map(toRaw));
      savedSnapshot.value = snapshot();
      attempted.value = false;
      activating.value = false;
      return true;
    } finally {
      saving.value = false;
    }
  };

  const openScenarios = async () => {
    scenarioDialog.value?.close();
    if (isDirty.value && !(await save())) return;
    router.push({
      name: 'captain_assistants_scenarios_index',
      params: { assistantId: assistant.value.id },
      query:
        existingScenario.value || guidedSetup.value
          ? {}
          : { template: 'capture_business_lead' },
    });
  };

  const openHubspotSettings = () =>
    router.push({ name: 'settings_integrations_hubspot' });

  const manageNotificationTeam = async () => {
    if (isDirty.value && !(await save())) return;
    const teamId = settings.value.lead_notification_team_id;
    router.push({
      name: teamId ? 'settings_teams_edit_members' : 'settings_teams_new',
      ...(teamId ? { params: { teamId } } : {}),
    });
  };

  const isHubspotConnected = computed(() =>
    ['mapped', 'mapping_needed', 'sync_off'].includes(hubspotState.value)
  );

  const hubspotSyncEnabled = computed(() =>
    ['mapped', 'mapping_needed'].includes(hubspotState.value)
  );

  const statusLabel = computed(() => {
    if (!settings.value.leads_enabled) return label('STATUS.OFF');
    if (loading.value) return label('STATUS.CHECKING');
    if (setup.scenarioError.value) return label('STATUS.UNKNOWN');
    if (captureScenario.value) return label('STATUS.READY');
    if (existingScenario.value) return label('STATUS.PAUSED_SCENARIO');
    return label('STATUS.NEEDS_SCENARIO');
  });
  const statusTone = computed(() => {
    if (!settings.value.leads_enabled) return 'paused';
    return !isDirty.value && captureScenario.value ? 'live' : 'attention';
  });

  const selectedTeamName = computed(
    () =>
      teams.value.find(
        team => team.id === settings.value.lead_notification_team_id
      )?.name || ''
  );

  const notificationStatus = computed(() => {
    if (teamsError.value) return 'unavailable';
    if (!settings.value.lead_notification_team_id) return 'off';
    if (
      settings.value.lead_notification_team_id !==
      assistant.value.config?.lead_notification_team_id
    )
      return 'save_to_check';
    return assistant.value.lead_notification_status || 'save_to_check';
  });

  // One sentence per step, for the closed card and the stepper.
  const S = 'CAPTAIN.ASSISTANTS.SETTINGS.LEADS.SETUP.SUMMARY';
  const askedLabels = computed(() => [
    t(`${S}.NAME_EMAIL`),
    ...settings.value.lead_fields
      .map(field => (field.label || field.key || '').toLowerCase())
      .filter(Boolean),
  ]);
  const listFormatter = new Intl.ListFormat('en', { type: 'conjunction' });
  const summaries = computed(() => ({
    ask: t(`${S}.ASK`, {
      details: listFormatter.format(askedLabels.value),
      count: settings.value.lead_max_questions,
    }),
    when: guidedSetup.value
      ? t(
          settings.value.lead_handoff_capture_enabled
            ? `${S}.WHEN_HANDOFF`
            : `${S}.WHEN`,
          {
            who: settings.value.lead_trigger || label('GUIDED.DEFAULT_TRIGGER'),
          }
        )
      : t('CAPTAIN.AGENT_UX.LEADS.CUSTOM_SCENARIO'),
    where: [
      t(`${S}.SAVED`),
      selectedTeamName.value
        ? `${t(`${S}.EMAIL_TEAM`, { team: selectedTeamName.value })}: ${label(`NOTIFICATION_STATUS.${notificationStatus.value.toUpperCase()}`)}`
        : t(teamsError.value ? `${S}.EMAIL_UNAVAILABLE` : `${S}.EMAIL_OFF`),
      t(`${S}.HUBSPOT_STATUS`, {
        status: label(`HUBSPOT.${hubspotState.value.toUpperCase()}`),
      }),
    ].join(' · '),
  }));

  const state = {
    label,
    settings,
    attempted,
    saving,
    setup,
    guidedSetup,
    teams,
    teamsError,
    isDirty,
    hasErrors,
    reset,
    save,
    activating,
    fieldErrorFor,
    fieldError,
    typeErrorFor,
    typeError,
    fieldKeyLocked,
    isFieldSelected,
    togglePresetField,
    openScenarios,
    openHubspotSettings,
    manageNotificationTeam,
    isHubspotConnected,
    hubspotSyncEnabled,
    statusLabel,
    statusTone,
    selectedTeamName,
    notificationStatus,
    summaries,
    scenarioDialog,
    canManageIntegrations,
    assistantName: computed(() => assistant.value.name || ''),
  };
  provide(KEY, state);
  return state;
}

export const useLeadSettings = () => inject(KEY);

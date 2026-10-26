<script setup>
import { computed, nextTick, onMounted, ref, toRaw, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import TeamsAPI from 'dashboard/api/teams';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import SettingsSwitchRow from './SettingsSwitchRow.vue';
import SettingsSaveBar from './SettingsSaveBar.vue';
import SettingsSplit from './SettingsSplit.vue';
import LeadCapturePreview from './LeadCapturePreview.vue';
import { useLeadSetup } from './useLeadSetup';

const props = defineProps({
  assistant: { type: Object, required: true },
  save: { type: Function, required: true },
  canManageIntegrations: { type: Boolean, default: false },
});

const { t } = useI18n();
const router = useRouter();
const store = useStore();
const contactAttributes = useMapGetter('attributes/getContactAttributes');

const label = (key, params = {}) =>
  t(`CAPTAIN.ASSISTANTS.SETTINGS.LEADS.${key}`, params);

const MAX_ENTRIES = 10;
const MAX_TEXT_LENGTH = 300;
const KEY_PATTERN = /^[a-z][a-z0-9_]{0,39}$/;
const RESERVED_KEYS = [
  'type',
  'summary',
  'source',
  'status',
  'visitor_city',
  'visitor_country',
  'visitor_country_code',
];
const COMMON_FIELDS = ['use_case', 'audience_size', 'company', 'country'];
const QUESTION_OPTIONS = [0, 1, 2, 3, 4, 5];
const TYPE_PRESETS = ['ENTERPRISE', 'PARTNERSHIP', 'NEEDS_REVIEW'];

const settings = ref({});
const savedSnapshot = ref('');
const saving = ref(false);
const attempted = ref(false);
const form = ref(null);

const setup = useLeadSetup(
  computed(() => props.assistant.id),
  computed(() => settings.value.lead_fields)
);

const {
  captureScenario,
  existingScenario,
  hubspotState,
  transcriptState,
  requiredMappingKeys,
  unmappedKeys,
  businessLeadsOnly,
  loading,
  scenarioError,
} = setup;

const guidedSetup = computed(
  () => settings.value.lead_guided_setup ?? !existingScenario.value
);
const guidedDialogRef = ref(null);
const adoptGuidedSetup = () => {
  settings.value.lead_guided_setup = true;
  guidedDialogRef.value?.close();
};

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
      !scenarioError.value &&
      !existingScenario.value)
);

let lockedFields = new WeakSet();
const fieldKeyLocked = field => lockedFields.has(toRaw(field));

const reset = () => {
  const config = props.assistant.config || {};
  settings.value = {
    leads_enabled: config.leads_enabled === true,
    lead_guided_setup: config.lead_guided_setup ?? null,
    lead_trigger: config.lead_trigger ?? label('GUIDED.DEFAULT_TRIGGER'),
    lead_instructions: config.lead_instructions ?? '',
    lead_max_questions: config.lead_max_questions ?? 2,
    lead_handoff_capture_enabled: config.lead_handoff_capture_enabled === true,
    lead_notification_team_id: config.lead_notification_team_id ?? null,
    published_pricing_enabled: config.published_pricing_enabled === true,
    lead_fields: (config.lead_fields || []).map(field => ({ ...field })),
    lead_types: (config.lead_types || []).map(type => ({ ...type })),
  };
  lockedFields = new WeakSet(settings.value.lead_fields.map(toRaw));
  savedSnapshot.value = snapshot();
  attempted.value = false;
};

watch(
  () => props.assistant.config,
  () => {
    if (!isDirty.value || saving.value || !savedSnapshot.value) reset();
  },
  { immediate: true }
);

const enableCapture = value => {
  settings.value.leads_enabled = value;
  if (
    value &&
    !props.assistant.config?.leads_enabled &&
    !settings.value.lead_fields.length
  ) {
    settings.value.lead_fields = ['use_case', 'audience_size', 'company'].map(
      key => ({
        key,
        label: label(`COMMON_FIELDS.${key}`),
      })
    );
  }
  if (value && !settings.value.lead_types.length) {
    settings.value.lead_types.push({
      name: 'business_inquiry',
      rule: label('DEFAULT_TYPE_RULE'),
    });
  }
};

const slugifyKey = text =>
  (text || '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 40);

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

const existingAttributeSuggestions = computed(() => {
  const standardSet = new Set([...COMMON_FIELDS, ...RESERVED_KEYS]);
  return (contactAttributes.value || [])
    .map(attr => {
      const rawKey = (attr.attributeKey || '').replace(/^lead_/, '');
      return {
        key: rawKey,
        label: attr.attributeDisplayName || rawKey,
      };
    })
    .filter(
      item =>
        KEY_PATTERN.test(item.key) &&
        !standardSet.has(item.key) &&
        !isFieldSelected(item.key)
    );
});

const customFieldChips = computed(() =>
  settings.value.lead_fields.filter(field => !COMMON_FIELDS.includes(field.key))
);

// Custom Field Dialog
const fieldDialogRef = ref(null);
const editingFieldIndex = ref(-1);
const fieldDraft = ref({ key: '', label: '', locked: false });
const fieldDraftAttempted = ref(false);

const suggestDraftKey = () => {
  if (fieldDraft.value.locked || fieldDraft.value.key) return;
  fieldDraft.value.key = slugifyKey(fieldDraft.value.label);
};

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

const fieldDraftError = computed(() =>
  fieldErrorFor(fieldDraft.value, editingFieldIndex.value)
);

const openFieldDialog = (index = -1) => {
  editingFieldIndex.value = index;
  fieldDraftAttempted.value = false;
  if (index >= 0) {
    const target = settings.value.lead_fields[index];
    fieldDraft.value = {
      key: target.key,
      label: target.label,
      locked: fieldKeyLocked(target),
    };
  } else {
    fieldDraft.value = { key: '', label: '', locked: false };
  }
  fieldDialogRef.value?.open();
};

const confirmFieldDialog = () => {
  suggestDraftKey();
  fieldDraftAttempted.value = true;
  if (fieldDraftError.value) return;
  const entry = {
    key: fieldDraft.value.key.trim(),
    label: fieldDraft.value.label.trim(),
  };
  if (editingFieldIndex.value >= 0) {
    Object.assign(settings.value.lead_fields[editingFieldIndex.value], entry);
  } else if (settings.value.lead_fields.length < MAX_ENTRIES) {
    settings.value.lead_fields.push(entry);
  }
  fieldDialogRef.value?.close();
};

const removeEditingField = () => {
  if (editingFieldIndex.value >= 0) {
    settings.value.lead_fields.splice(editingFieldIndex.value, 1);
  }
  fieldDialogRef.value?.close();
};

// Lead Type Dialog
const typeDialogRef = ref(null);
const editingTypeIndex = ref(-1);
const typeDraft = ref({ name: '', rule: '' });
const typeDraftAttempted = ref(false);

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

const typeDraftError = computed(() =>
  typeErrorFor(typeDraft.value, editingTypeIndex.value)
);

const openTypeDialog = (index = -1) => {
  editingTypeIndex.value = index;
  typeDraftAttempted.value = false;
  if (index >= 0) {
    const target = settings.value.lead_types[index];
    typeDraft.value = { name: target.name, rule: target.rule };
  } else {
    typeDraft.value = { name: '', rule: '' };
  }
  typeDialogRef.value?.open();
};

const applyTypePreset = presetKey => {
  typeDraft.value = {
    name: label(`TYPE_PRESETS.${presetKey}.NAME`),
    rule: label(`TYPE_PRESETS.${presetKey}.RULE`),
  };
};

const confirmTypeDialog = () => {
  typeDraftAttempted.value = true;
  if (typeDraftError.value) return;
  const entry = {
    name: typeDraft.value.name.trim(),
    rule: typeDraft.value.rule.trim(),
  };
  if (editingTypeIndex.value >= 0) {
    settings.value.lead_types.splice(editingTypeIndex.value, 1, entry);
  } else if (settings.value.lead_types.length < MAX_ENTRIES) {
    settings.value.lead_types.push(entry);
  }
  typeDialogRef.value?.close();
};

const removeEditingType = () => {
  if (editingTypeIndex.value >= 0) {
    settings.value.lead_types.splice(editingTypeIndex.value, 1);
  }
  typeDialogRef.value?.close();
};

// Scenario & HubSpot Modals
const scenarioDialogRef = ref(null);
const hubspotDialogRef = ref(null);

const hasErrors = computed(
  () =>
    (settings.value.leads_enabled && !settings.value.lead_types.length) ||
    settings.value.lead_fields.some(fieldError) ||
    settings.value.lead_types.some(typeError)
);

const save = async () => {
  if (saving.value || loading.value || scenarioError.value) return false;
  attempted.value = true;
  if (hasErrors.value) {
    await nextTick();
    form.value?.querySelector('[aria-invalid="true"]')?.focus();
    return false;
  }
  saving.value = true;
  try {
    const config = {
      ...JSON.parse(snapshot()),
      lead_guided_setup: guidedSetup.value,
    };
    const result = await props.save({ config });
    if (result === false) return false;
    store.dispatch('attributes/get');
    setup.refresh();
    savedSnapshot.value = snapshot();
    attempted.value = false;
    return true;
  } finally {
    saving.value = false;
  }
};

const openScenarios = async () => {
  scenarioDialogRef.value?.close();
  if (isDirty.value && !(await save())) return;
  router.push({
    name: 'captain_assistants_scenarios_index',
    params: { assistantId: props.assistant.id },
    query: existingScenario.value ? {} : { template: 'capture_business_lead' },
  });
};

const openHubspotSettings = () => {
  hubspotDialogRef.value?.close();
  router.push({ name: 'settings_integrations_hubspot' });
};

const hubspotLabel = computed(() =>
  label(`HUBSPOT.${hubspotState.value.toUpperCase()}`)
);
const transcriptLabel = computed(() =>
  label(`TRANSCRIPT.${transcriptState.value.toUpperCase()}`)
);
const statusLabel = computed(() => {
  if (isDirty.value) return label('STATUS.UNSAVED');
  if (!settings.value.leads_enabled) return label('STATUS.OFF');
  if (loading.value) return label('STATUS.CHECKING');
  if (scenarioError.value) return label('STATUS.UNKNOWN');
  if (captureScenario.value) return label('STATUS.READY');
  if (existingScenario.value) return label('STATUS.PAUSED_SCENARIO');
  return label('STATUS.NEEDS_SCENARIO');
});

const selectedTeamName = computed(
  () =>
    teams.value.find(
      team => team.id === settings.value.lead_notification_team_id
    )?.name || ''
);

const isHubspotConnected = computed(
  () => !['not_connected', 'loading'].includes(hubspotState.value)
);
</script>

<template>
  <form ref="form" class="flex flex-col gap-6" @submit.prevent="save">
    <fieldset
      :disabled="saving"
      class="m-0 flex min-w-0 flex-col gap-6 border-0 p-0"
    >
      <!-- Hero Bar: Master Toggle + Scenario Readiness Pill -->
      <section
        class="flex flex-col gap-3 rounded-2xl bg-n-solid-1 px-5 py-3 outline outline-1 outline-n-weak sm:flex-row sm:items-center sm:justify-between"
      >
        <SettingsSwitchRow
          class="flex-1 !py-1"
          :model-value="settings.leads_enabled"
          :title="label('ENABLE')"
          :description="label('ENABLE_DESCRIPTION')"
          @update:model-value="enableCapture"
        />
        <div class="flex shrink-0 items-center gap-2">
          <button
            type="button"
            class="flex items-center gap-2 rounded-full bg-n-alpha-1 px-3.5 py-1.5 text-xs font-medium text-n-slate-12 outline outline-1 outline-n-weak transition-colors hover:outline-n-strong"
            @click="scenarioDialogRef?.open()"
          >
            <span
              class="size-2 rounded-full"
              :class="
                !isDirty && settings.leads_enabled && captureScenario
                  ? 'bg-n-teal-9'
                  : settings.leads_enabled
                    ? 'bg-n-amber-9'
                    : 'bg-n-slate-8'
              "
              aria-hidden="true"
            />
            <span>{{ statusLabel }}</span>
            <span class="i-lucide-chevron-right size-3.5 text-n-slate-10" />
          </button>
        </div>
      </section>

      <SettingsSplit>
        <div
          class="flex flex-col gap-5 transition-opacity"
          :class="{ 'opacity-60': !settings.leads_enabled }"
        >
          <section
            class="flex flex-col gap-4 rounded-2xl bg-n-solid-1 p-5 outline outline-1 outline-n-weak"
          >
            <h3 class="m-0 text-sm font-semibold text-n-slate-12">
              {{ label('GUIDED.TITLE') }}
            </h3>
            <template v-if="guidedSetup">
              <label
                class="m-0 flex flex-col gap-1.5 text-sm font-medium text-n-slate-12"
              >
                {{ label('GUIDED.TRIGGER') }}
                <textarea
                  v-model="settings.lead_trigger"
                  rows="3"
                  maxlength="500"
                  :placeholder="label('GUIDED.DEFAULT_TRIGGER')"
                  class="m-0 w-full resize-y rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-sm font-normal text-n-slate-12 placeholder:text-n-slate-10 focus:border-n-brand focus:outline-none"
                />
              </label>
              <label
                class="m-0 flex flex-col gap-1.5 text-sm font-medium text-n-slate-12"
              >
                {{ label('GUIDED.NOTES') }}
                <textarea
                  v-model="settings.lead_instructions"
                  rows="3"
                  maxlength="2000"
                  :placeholder="label('GUIDED.NOTES_PLACEHOLDER')"
                  class="m-0 w-full resize-y rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-sm font-normal text-n-slate-12 placeholder:text-n-slate-10 focus:border-n-brand focus:outline-none"
                />
              </label>
              <p class="m-0 text-xs text-n-slate-11">
                {{ label('GUIDED.HELP') }}
              </p>
            </template>
            <template v-else>
              <p class="m-0 text-xs text-n-slate-11">
                {{ label('GUIDED.CUSTOM_HELP') }}
              </p>
              <Button
                type="button"
                size="sm"
                variant="faded"
                :label="label('GUIDED.SWITCH')"
                :disabled="loading || scenarioError"
                @click="guidedDialogRef?.open()"
              />
            </template>
          </section>

          <!-- BENTO CARD 1: WHAT TO COLLECT & PACING -->
          <section
            class="flex flex-col gap-4 rounded-2xl bg-n-solid-1 p-5 outline outline-1 outline-n-weak"
          >
            <div class="flex items-start justify-between gap-3">
              <div>
                <h3 class="m-0 text-sm font-semibold text-n-slate-12">
                  {{ label('FIELDS') }}
                </h3>
                <p class="mb-0 mt-0.5 text-xs text-n-slate-11">
                  {{ label('FIELDS_HELP') }}
                </p>
              </div>
              <span
                class="shrink-0 rounded-full bg-n-alpha-1 px-2.5 py-0.5 text-xs font-medium text-n-slate-11 outline outline-1 outline-n-weak"
              >
                {{ settings.lead_fields.length }} / {{ MAX_ENTRIES }}
              </span>
            </div>

            <!-- Check-Chips Grid (Always Included + Common Presets + Custom Fields) -->
            <div class="flex flex-wrap gap-2">
              <span
                class="inline-flex items-center gap-1.5 rounded-xl bg-n-slate-2 px-3 py-1.5 text-xs font-medium text-n-slate-11"
              >
                <span class="i-lucide-check size-3.5 text-n-teal-10" />
                {{ label('ALWAYS_NAME_EMAIL') }}
              </span>
              <span
                class="inline-flex items-center gap-1.5 rounded-xl bg-n-slate-2 px-3 py-1.5 text-xs font-medium text-n-slate-11"
              >
                <span class="i-lucide-check size-3.5 text-n-teal-10" />
                {{ label('ALWAYS_SUMMARY') }}
              </span>
              <span
                class="inline-flex items-center gap-1.5 rounded-xl bg-n-slate-2 px-3 py-1.5 text-xs font-medium text-n-slate-11"
              >
                <span class="i-lucide-map-pin size-3.5 text-n-teal-10" />
                {{ label('GUIDED.LOCATION_INCLUDED') }}
              </span>

              <!-- Common Field Toggle Chips -->
              <button
                v-for="key in COMMON_FIELDS"
                :key="key"
                type="button"
                :aria-pressed="isFieldSelected(key)"
                class="inline-flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-xs font-medium transition-colors"
                :class="
                  isFieldSelected(key)
                    ? 'bg-n-blue-1 text-n-blue-11 outline outline-2 outline-n-blue-9'
                    : 'bg-n-alpha-1 text-n-slate-12 outline outline-1 outline-n-weak hover:outline-n-strong'
                "
                @click="togglePresetField(key, label(`COMMON_FIELDS.${key}`))"
              >
                <span
                  :class="
                    isFieldSelected(key) ? 'i-lucide-check' : 'i-lucide-plus'
                  "
                  class="size-3.5"
                />
                {{ label(`COMMON_FIELDS.${key}`) }}
              </button>

              <!-- Existing Account Contact Custom Attribute Suggestions -->
              <button
                v-for="attr in existingAttributeSuggestions"
                :key="attr.key"
                type="button"
                class="inline-flex items-center gap-1.5 rounded-xl bg-n-alpha-1 px-3 py-1.5 text-xs font-medium text-n-slate-11 outline outline-1 outline-n-weak transition-colors hover:text-n-slate-12 hover:outline-n-strong"
                @click="togglePresetField(attr.key, attr.label)"
              >
                <span class="i-lucide-plus size-3.5" />
                {{ attr.label }}
              </button>

              <!-- Custom Field Chips (Click to Edit) -->
              <button
                v-for="field in customFieldChips"
                :key="field.key || field.label"
                type="button"
                :aria-invalid="attempted && !!fieldError(field)"
                class="inline-flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-xs font-medium transition-colors"
                :class="
                  attempted && fieldError(field)
                    ? 'bg-n-ruby-2 text-n-ruby-11 outline outline-2 outline-n-ruby-9'
                    : 'bg-n-blue-1 text-n-blue-11 outline outline-2 outline-n-blue-9'
                "
                @click="openFieldDialog(settings.lead_fields.indexOf(field))"
              >
                <span class="i-lucide-sliders-horizontal size-3" />
                <span>{{ field.label || field.key }}</span>
              </button>

              <button
                v-if="settings.lead_fields.length < MAX_ENTRIES"
                type="button"
                class="inline-flex items-center gap-1.5 rounded-xl border border-dashed border-n-strong bg-transparent px-3 py-1.5 text-xs font-medium text-n-slate-11 transition-colors hover:border-n-brand hover:text-n-slate-12"
                @click="openFieldDialog(-1)"
              >
                <span class="i-lucide-plus size-3.5" />
                {{ label('ADD_FIELD') }}
              </button>
            </div>

            <p class="m-0 text-xs text-n-slate-11">
              {{ label('GUIDED.LOCATION_HELP') }}
            </p>
            <details class="group">
              <summary
                class="cursor-pointer text-xs font-medium text-n-slate-11"
              >
                {{ label('GUIDED.PACING') }}
              </summary>
              <div
                class="flex flex-col gap-2.5 border-t border-n-weak pt-3.5 sm:flex-row sm:items-center sm:justify-between"
              >
                <div class="flex flex-col gap-0.5">
                  <span class="text-xs font-medium text-n-slate-12">
                    {{ label('MAX_QUESTIONS') }}
                  </span>
                  <span class="text-xs text-n-slate-11">
                    {{ label('QUESTIONS_HELP') }}
                  </span>
                </div>
                <div
                  class="flex shrink-0 self-start rounded-xl bg-n-alpha-1 p-1 outline outline-1 outline-n-weak"
                  role="radiogroup"
                  :aria-label="label('MAX_QUESTIONS')"
                >
                  <button
                    v-for="count in QUESTION_OPTIONS"
                    :key="count"
                    type="button"
                    role="radio"
                    :aria-checked="settings.lead_max_questions === count"
                    class="rounded-lg px-2.5 py-1 text-xs font-semibold transition-colors"
                    :class="
                      settings.lead_max_questions === count
                        ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
                        : 'text-n-slate-11 hover:text-n-slate-12'
                    "
                    @click="settings.lead_max_questions = count"
                  >
                    {{ count === 0 ? label('NONE_QUESTIONS') : count }}
                  </button>
                </div>
              </div>
            </details>
          </section>

          <!-- Optional business-specific categorization. -->
          <details
            class="flex flex-col gap-3 rounded-2xl bg-n-solid-1 p-5 outline outline-1 outline-n-weak"
          >
            <summary
              class="cursor-pointer text-sm font-semibold text-n-slate-12"
            >
              {{ label('GUIDED.CATEGORIES') }}
            </summary>
            <div class="flex items-start justify-between gap-3">
              <div>
                <div class="flex items-center gap-2">
                  <h3 class="m-0 text-sm font-semibold text-n-slate-12">
                    {{ label('TYPES') }}
                  </h3>
                  <span
                    class="rounded-md bg-n-blue-2 px-2 py-0.5 text-xs font-medium text-n-blue-11"
                  >
                    {{ label('LIST_ATTRIBUTE_BADGE') }}
                  </span>
                </div>
                <p class="mb-0 mt-0.5 text-xs text-n-slate-11">
                  {{ label('TYPES_HELP') }}
                </p>
              </div>
              <Button
                v-if="settings.lead_types.length < MAX_ENTRIES"
                type="button"
                variant="faded"
                size="xs"
                icon="i-lucide-plus"
                :label="label('ADD_TYPE')"
                @click="openTypeDialog(-1)"
              />
            </div>

            <div
              v-if="settings.lead_types.length"
              class="flex flex-col divide-y divide-n-weak -mx-2"
            >
              <div
                v-for="(type, index) in settings.lead_types"
                :key="index"
                class="flex items-center justify-between gap-3 rounded-xl px-2.5 py-2.5 transition-colors hover:bg-n-alpha-1"
              >
                <button
                  type="button"
                  :aria-invalid="attempted && !!typeError(type)"
                  class="flex min-w-0 flex-1 flex-col items-start gap-0.5 text-start"
                  @click="openTypeDialog(index)"
                >
                  <span class="flex items-center gap-2">
                    <code
                      class="rounded-md bg-n-alpha-2 px-2 py-0.5 font-mono text-xs font-semibold text-n-slate-12"
                    >
                      {{ type.name || label('TYPE_NAME') }}
                    </code>
                    <span
                      v-if="attempted && typeError(type)"
                      class="text-xs text-n-ruby-11"
                    >
                      {{ typeError(type) }}
                    </span>
                  </span>
                  <span class="w-full truncate text-xs text-n-slate-11">
                    {{ type.rule || label('RULE_PLACEHOLDER') }}
                  </span>
                </button>
                <div class="flex shrink-0 items-center gap-1">
                  <Button
                    type="button"
                    variant="ghost"
                    color="slate"
                    size="xs"
                    icon="i-lucide-pencil"
                    :aria-label="type.name || label('TYPE_NAME')"
                    @click="openTypeDialog(index)"
                  />
                  <Button
                    type="button"
                    variant="ghost"
                    color="slate"
                    size="xs"
                    icon="i-lucide-trash-2"
                    :aria-label="
                      label('REMOVE_TYPE', {
                        name: type.name || label('TYPE_NAME'),
                      })
                    "
                    @click="settings.lead_types.splice(index, 1)"
                  />
                </div>
              </div>
            </div>

            <p
              v-else
              class="m-0 rounded-xl bg-n-alpha-1 px-3.5 py-3 text-xs"
              :class="
                attempted && settings.leads_enabled
                  ? 'text-n-ruby-11 outline outline-1 outline-n-ruby-8'
                  : 'text-n-slate-11'
              "
            >
              {{ label('NO_TYPES') }}
            </p>
          </details>

          <!-- BENTO CARD 3: DELIVERY & SMART BEHAVIORS -->
          <section
            class="flex flex-col divide-y divide-n-weak rounded-2xl bg-n-solid-1 px-5 py-4 outline outline-1 outline-n-weak"
          >
            <header class="pb-3">
              <h3 class="m-0 text-sm font-semibold text-n-slate-12">
                {{ label('FOLLOW_UP') }}
              </h3>
              <p class="mb-0 mt-0.5 text-xs text-n-slate-11">
                {{ label('FOLLOW_UP_HELP') }}
              </p>
            </header>

            <!-- Row 1: Team Email Notification -->
            <div
              class="flex flex-col gap-2.5 py-3.5 sm:flex-row sm:items-center sm:justify-between"
            >
              <div class="flex min-w-0 flex-col gap-0.5">
                <label
                  for="lead-notification-team"
                  class="text-sm font-medium text-n-slate-12"
                >
                  {{ label('NOTIFICATION_TITLE') }}
                </label>
                <span class="text-xs text-n-slate-11">
                  {{
                    label(
                      teamsError ? 'NOTIFICATION_ERROR' : 'NOTIFICATION_HELP'
                    )
                  }}
                </span>
              </div>
              <select
                id="lead-notification-team"
                v-model="settings.lead_notification_team_id"
                :disabled="teamsError"
                class="m-0 w-full shrink-0 rounded-xl border border-n-weak bg-n-alpha-1 px-3 py-2 text-xs font-medium text-n-slate-12 sm:w-44"
              >
                <option :value="null">{{ label('NOTIFICATION_OFF') }}</option>
                <option v-for="team in teams" :key="team.id" :value="team.id">
                  {{ team.name }}
                </option>
              </select>
            </div>

            <!-- Row 2: Optional HubSpot CRM Row (Action Row -> Modal) -->
            <div class="flex items-center justify-between gap-3 py-3.5">
              <div class="flex min-w-0 flex-col gap-0.5">
                <div class="flex items-center gap-2">
                  <span class="text-sm font-medium text-n-slate-12">
                    {{ label('HUBSPOT_TITLE') }}
                  </span>
                  <span
                    class="rounded-full px-2 py-0.5 text-xs font-medium"
                    :class="
                      hubspotState === 'mapped'
                        ? 'bg-n-teal-3 text-n-teal-11'
                        : isHubspotConnected
                          ? 'bg-n-amber-3 text-n-amber-11'
                          : 'bg-n-slate-3 text-n-slate-11'
                    "
                  >
                    {{
                      unmappedKeys.length
                        ? label('UNMAPPED_COUNT', {
                            count: unmappedKeys.length,
                          })
                        : label('OPTIONAL_BADGE')
                    }}
                  </span>
                </div>
                <span class="text-xs text-n-slate-11" role="status">
                  {{ hubspotLabel }}
                </span>
              </div>
              <Button
                type="button"
                variant="faded"
                color="slate"
                size="xs"
                icon="i-lucide-sliders-horizontal"
                :label="label('HUBSPOT_DETAILS')"
                @click="hubspotDialogRef?.open()"
              />
            </div>

            <!-- Row 3: Capture Across Human Handoff -->
            <SettingsSwitchRow
              :model-value="settings.lead_handoff_capture_enabled"
              :title="label('HANDOFF_TITLE')"
              :description="label('HANDOFF_HELP')"
              @update:model-value="
                settings.lead_handoff_capture_enabled = $event
              "
            />

            <!-- Row 4: Published Service Pricing -->
            <SettingsSwitchRow
              :model-value="settings.published_pricing_enabled"
              :title="label('PRICING_TITLE')"
              :description="label('PRICING_HELP')"
              @update:model-value="settings.published_pricing_enabled = $event"
            />
          </section>
        </div>

        <template #preview>
          <LeadCapturePreview
            :enabled="settings.leads_enabled"
            :fields="settings.lead_fields"
            :types="settings.lead_types"
            :max-questions="settings.lead_max_questions"
            :handoff-capture="settings.lead_handoff_capture_enabled"
            :team-name="selectedTeamName"
          />
        </template>
      </SettingsSplit>
    </fieldset>

    <p
      v-if="attempted && hasErrors"
      class="m-0 text-sm text-n-ruby-11"
      role="alert"
    >
      {{ label('ERRORS.FORM') }}
    </p>

    <SettingsSaveBar
      :is-dirty="isDirty"
      :is-saving="saving"
      @save="save"
      @discard="reset"
    />

    <Dialog
      ref="guidedDialogRef"
      :title="label('GUIDED.SWITCH')"
      :confirm-button-label="label('GUIDED.SWITCH')"
      @confirm="adoptGuidedSetup"
    >
      <p class="m-0 text-sm text-n-slate-11">
        {{ label('GUIDED.SWITCH_HELP') }}
      </p>
    </Dialog>

    <!-- PROGRESSIVE DISCLOSURE DIALOG 1: ADD / EDIT CUSTOM ATTRIBUTE FIELD -->
    <Dialog
      ref="fieldDialogRef"
      width="md"
      :title="
        editingFieldIndex >= 0 ? label('EDIT_FIELD_TITLE') : label('ADD_FIELD')
      "
      :confirm-button-label="label('APPLY')"
      @confirm="confirmFieldDialog"
    >
      <div class="flex flex-col gap-3">
        <Input
          v-model="fieldDraft.label"
          :label="label('FIELD_LABEL')"
          :maxlength="MAX_TEXT_LENGTH"
          :placeholder="label('FIELD_PLACEHOLDER')"
          autofocus
          @blur="suggestDraftKey"
        />
        <details>
          <summary class="cursor-pointer text-xs font-medium text-n-slate-11">
            {{ label('GUIDED.ATTRIBUTE_SETTINGS') }}
          </summary>
          <Input
            v-model="fieldDraft.key"
            :label="label('FIELD_KEY')"
            :disabled="fieldDraft.locked"
            :maxlength="40"
            :placeholder="label('KEY_PLACEHOLDER')"
          />
          <p class="m-0 text-xs text-n-slate-11">
            {{ label(fieldDraft.locked ? 'KEY_LOCKED' : 'KEY_HELP') }}
          </p>
        </details>
        <p
          v-if="fieldDraftAttempted && fieldDraftError"
          class="m-0 text-xs text-n-ruby-11"
          role="alert"
        >
          {{ fieldDraftError }}
        </p>
        <div v-if="editingFieldIndex >= 0" class="pt-1">
          <Button
            type="button"
            variant="ghost"
            color="ruby"
            size="xs"
            icon="i-lucide-trash-2"
            :label="
              label('REMOVE_FIELD', {
                name: fieldDraft.label || fieldDraft.key,
              })
            "
            @click="removeEditingField"
          />
        </div>
      </div>
    </Dialog>

    <!-- PROGRESSIVE DISCLOSURE DIALOG 2: ADD / EDIT LEAD TYPE -->
    <Dialog
      ref="typeDialogRef"
      width="md"
      :title="
        editingTypeIndex >= 0 ? label('EDIT_TYPE_TITLE') : label('ADD_TYPE')
      "
      :confirm-button-label="label('APPLY')"
      @confirm="confirmTypeDialog"
    >
      <div class="flex flex-col gap-3">
        <div v-if="editingTypeIndex < 0" class="flex flex-wrap gap-1.5">
          <button
            v-for="preset in TYPE_PRESETS"
            :key="preset"
            type="button"
            class="rounded-lg bg-n-alpha-1 px-2.5 py-1 text-xs font-medium text-n-slate-12 outline outline-1 outline-n-weak hover:outline-n-strong"
            @click="applyTypePreset(preset)"
          >
            + {{ label(`TYPE_PRESETS.${preset}.LABEL`) }}
          </button>
        </div>
        <Input
          v-model="typeDraft.name"
          :label="label('TYPE_NAME')"
          :maxlength="MAX_TEXT_LENGTH"
          :placeholder="label('TYPE_PLACEHOLDER')"
          autofocus
        />
        <label
          class="m-0 flex flex-col gap-1.5 text-sm font-medium text-n-slate-12"
        >
          {{ label('TYPE_RULE') }}
          <textarea
            v-model="typeDraft.rule"
            rows="3"
            :maxlength="MAX_TEXT_LENGTH"
            :placeholder="label('RULE_PLACEHOLDER')"
            class="m-0 w-full resize-y rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-sm font-normal text-n-slate-12 placeholder:text-n-slate-10 focus:border-n-brand focus:outline-none"
          />
        </label>
        <p class="m-0 text-xs text-n-slate-11">
          {{ label('FALLBACK_HELP') }}
        </p>
        <p
          v-if="typeDraftAttempted && typeDraftError"
          class="m-0 text-xs text-n-ruby-11"
          role="alert"
        >
          {{ typeDraftError }}
        </p>
        <div v-if="editingTypeIndex >= 0" class="pt-1">
          <Button
            type="button"
            variant="ghost"
            color="ruby"
            size="xs"
            icon="i-lucide-trash-2"
            :label="
              label('REMOVE_TYPE', {
                name: typeDraft.name || label('TYPE_NAME'),
              })
            "
            @click="removeEditingType"
          />
        </div>
      </div>
    </Dialog>

    <!-- PROGRESSIVE DISCLOSURE DIALOG 3: SCENARIO & PRE-FLIGHT CHECKLIST -->
    <Dialog
      ref="scenarioDialogRef"
      width="lg"
      :title="label('SCENARIO_TITLE')"
      :show-confirm-button="false"
      :cancel-button-label="label('CLOSE')"
    >
      <div class="flex flex-col gap-4">
        <div
          class="flex flex-col gap-2 rounded-xl bg-n-alpha-1 p-3.5 outline outline-1 outline-n-weak"
        >
          <span class="text-xs font-medium text-n-slate-12">
            {{
              loading
                ? label('STATUS.CHECKING')
                : scenarioError
                  ? label('SCENARIO_ERROR')
                  : captureScenario
                    ? label('SCENARIO_FOUND', { name: captureScenario.title })
                    : existingScenario
                      ? label('SCENARIO_PAUSED', {
                          name: existingScenario.title,
                        })
                      : label('SCENARIO_MISSING')
            }}
          </span>
          <div class="flex flex-wrap items-center gap-2 pt-1">
            <Button
              type="button"
              size="xs"
              variant="faded"
              icon="i-lucide-git-branch"
              :disabled="!settings.leads_enabled || loading || scenarioError"
              :is-loading="saving"
              :label="
                label(
                  existingScenario
                    ? 'MANAGE_SCENARIO'
                    : isDirty
                      ? 'SAVE_ADD_SCENARIO'
                      : 'ADD_SCENARIO'
                )
              "
              @click="openScenarios"
            />
            <Button
              type="button"
              variant="ghost"
              color="slate"
              size="xs"
              icon="i-lucide-refresh-cw"
              :label="label('REFRESH')"
              :is-loading="loading"
              @click="setup.refresh"
            />
          </div>
        </div>

        <div class="flex flex-col gap-2">
          <span class="text-xs font-semibold text-n-slate-12">
            {{ label('TEST_TITLE') }}
          </span>
          <p class="m-0 text-xs text-n-slate-11">
            {{ label('TEST_HELP') }}
          </p>
          <ol
            class="m-0 flex list-decimal flex-col gap-1.5 ps-5 text-xs text-n-slate-12"
          >
            <li
              v-for="step in [
                'BUSINESS',
                'HANDOFF',
                'VIEWER',
                'REFUSAL',
                'DELIVERY',
              ]"
              :key="step"
            >
              {{ label(`TEST_${step}`) }}
            </li>
          </ol>
        </div>
      </div>
    </Dialog>

    <!-- PROGRESSIVE DISCLOSURE DIALOG 4: HUBSPOT CRM & TRANSCRIPTS -->
    <Dialog
      ref="hubspotDialogRef"
      width="md"
      :title="label('HUBSPOT_TITLE')"
      :show-confirm-button="false"
      :cancel-button-label="label('CLOSE')"
    >
      <div class="flex flex-col gap-4">
        <div
          class="flex flex-col gap-1 rounded-xl bg-n-alpha-1 p-3.5 outline outline-1 outline-n-weak"
        >
          <span class="text-xs font-semibold text-n-slate-12">
            {{ hubspotLabel }}
          </span>
          <p class="m-0 text-xs text-n-slate-11">
            {{ label('VERIFICATION') }}
          </p>
        </div>

        <div
          v-if="isHubspotConnected && requiredMappingKeys.length"
          class="flex flex-col divide-y divide-n-weak rounded-xl bg-n-alpha-1 px-3.5 outline outline-1 outline-n-weak"
        >
          <div
            v-for="key in requiredMappingKeys"
            :key="key"
            class="flex items-center justify-between py-2 text-xs"
          >
            <code class="font-mono text-n-slate-12">{{ key }}</code>
            <span
              class="font-medium"
              :class="
                unmappedKeys.includes(key)
                  ? 'text-n-amber-11'
                  : 'text-n-teal-11'
              "
            >
              {{
                label(
                  unmappedKeys.includes(key) ? 'FIELD_UNMAPPED' : 'FIELD_MAPPED'
                )
              }}
            </span>
          </div>
        </div>

        <div
          class="flex flex-col gap-1 rounded-xl bg-n-alpha-1 p-3.5 outline outline-1 outline-n-weak"
        >
          <span class="text-xs font-semibold text-n-slate-12">
            {{ label('TRANSCRIPT_TITLE') }}
          </span>
          <span class="text-xs text-n-slate-11">{{ transcriptLabel }}</span>
          <p class="mb-0 mt-1 text-xs text-n-slate-11">
            {{
              label(
                businessLeadsOnly ? 'TRANSCRIPT_LEADS_HELP' : 'TRANSCRIPT_HELP'
              )
            }}
          </p>
        </div>

        <div class="flex flex-wrap items-center justify-between gap-2">
          <Button
            type="button"
            variant="ghost"
            color="slate"
            size="xs"
            icon="i-lucide-refresh-cw"
            :label="label('REFRESH')"
            :is-loading="loading"
            @click="setup.refresh"
          />
          <Button
            v-if="canManageIntegrations"
            type="button"
            size="xs"
            variant="faded"
            :label="label('HUBSPOT_ACTION')"
            @click="openHubspotSettings"
          />
        </div>
      </div>
    </Dialog>
  </form>
</template>

<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

const props = defineProps({
  settings: { type: Object, required: true },
  properties: { type: Array, required: true },
  sources: { type: Array, required: true },
  isSaving: { type: Boolean, default: false },
});

const emit = defineEmits(['save']);

const { t } = useI18n();

const FIXED_KEYS = [
  'email',
  'firstname',
  'lastname',
  'phone',
  'lead_type',
  'lead_summary',
  'lead_source',
];
// Lead rows suggest the properties created for earlier private-app setups, when the portal has them.
const LEAD_PROPERTY_PREFIX = 'chatoctave_';

const syncContacts = ref(true);
const saveTranscripts = ref(true);
const contactSyncScope = ref('all_contacts');
const rowKeys = ref([]);
const mapping = ref({});
const addPickerKey = ref(0);
const configuredLeadKeys = computed(() =>
  props.sources
    .filter(source => source.kind === 'lead')
    .map(source => source.key)
);
const automaticKeys = computed(
  () => new Set([...FIXED_KEYS, ...configuredLeadKeys.value])
);

const propertyNames = computed(
  () => new Set(props.properties.map(property => property.name))
);
const propertyOptions = computed(() =>
  props.properties.map(property => ({
    value: property.name,
    label: `${property.label} (${property.name})`,
  }))
);
const sourceLabels = computed(() =>
  Object.fromEntries(props.sources.map(source => [source.key, source.label]))
);
const addableSources = computed(() =>
  props.sources
    .filter(source => !rowKeys.value.includes(source.key))
    .map(source => ({ value: source.key, label: source.label }))
);

const suggestedProperty = key => {
  const name = `${LEAD_PROPERTY_PREFIX}${key}`;
  return key.startsWith('lead_') && propertyNames.value.has(name) ? name : '';
};

const reset = () => {
  const saved = props.settings.field_mapping || {};
  const suggestLeadProperties = !Object.keys(saved).some(key =>
    key.startsWith('lead_')
  );
  syncContacts.value = props.settings.sync_contacts !== false;
  saveTranscripts.value = props.settings.save_transcripts !== false;
  contactSyncScope.value = props.settings.contact_sync_scope || 'all_contacts';
  rowKeys.value = [
    ...new Set([
      ...FIXED_KEYS,
      ...configuredLeadKeys.value,
      ...Object.keys(saved).filter(key => !FIXED_KEYS.includes(key)),
    ]),
  ];
  mapping.value = Object.fromEntries(
    rowKeys.value.map(key => [
      key,
      saved[key] || (suggestLeadProperties ? suggestedProperty(key) : ''),
    ])
  );
  mapping.value.email = 'email';
};

watch(() => props.settings, reset, { immediate: true });
// Source fields may arrive after settings. Add new lead rows without replacing
// destinations the administrator has already selected in this draft.
watch(configuredLeadKeys, keys => {
  keys.forEach(key => {
    if (rowKeys.value.includes(key)) return;
    rowKeys.value.push(key);
    mapping.value[key] =
      props.settings.field_mapping?.[key] || suggestedProperty(key);
  });
});

const duplicateProperties = computed(() => {
  const used = Object.values(mapping.value).filter(Boolean);
  return new Set(used.filter((name, index) => used.indexOf(name) !== index));
});

const addRow = key => {
  if (!key) return;
  rowKeys.value.push(key);
  mapping.value[key] = suggestedProperty(key);
  addPickerKey.value += 1;
};

const removeRow = key => {
  rowKeys.value = rowKeys.value.filter(rowKey => rowKey !== key);
  delete mapping.value[key];
};

const save = () => {
  emit('save', {
    field_mapping: Object.fromEntries(
      rowKeys.value
        .filter(key => mapping.value[key])
        .map(key => [key, mapping.value[key]])
    ),
    sync_contacts: syncContacts.value,
    save_transcripts: saveTranscripts.value,
    contact_sync_scope: contactSyncScope.value,
  });
};
</script>

<template>
  <form class="flex flex-col gap-6" @submit.prevent="save">
    <section
      class="flex flex-col gap-4 p-6 outline outline-1 outline-n-container bg-n-card rounded-xl"
    >
      <label class="flex items-start justify-between gap-4">
        <span class="flex flex-col gap-1">
          <span class="text-heading-3 text-n-slate-12">
            {{ t('INTEGRATION_SETTINGS.HUBSPOT.SYNC_CONTACTS.TITLE') }}
          </span>
          <span class="text-body-main text-n-slate-11">
            {{ t('INTEGRATION_SETTINGS.HUBSPOT.SYNC_CONTACTS.DESCRIPTION') }}
          </span>
        </span>
        <Switch v-model="syncContacts" data-test="sync-contacts" />
      </label>
      <label class="flex flex-col gap-2">
        <span class="text-heading-3 text-n-slate-12">{{
          t('INTEGRATION_SETTINGS.HUBSPOT.SCOPE.TITLE')
        }}</span>
        <select
          v-model="contactSyncScope"
          class="m-0 rounded-lg border border-n-weak bg-n-card px-3 py-2 text-sm text-n-slate-12"
          data-test="contact-sync-scope"
        >
          <option value="all_contacts">
            {{ t('INTEGRATION_SETTINGS.HUBSPOT.SCOPE.ALL') }}
          </option>
          <option value="business_leads">
            {{ t('INTEGRATION_SETTINGS.HUBSPOT.SCOPE.LEADS') }}
          </option>
        </select>
        <span class="text-body-main text-n-slate-11">{{
          t('INTEGRATION_SETTINGS.HUBSPOT.SCOPE.DESCRIPTION')
        }}</span>
      </label>
      <label class="flex items-start justify-between gap-4">
        <span class="flex flex-col gap-1">
          <span class="text-heading-3 text-n-slate-12">
            {{ t('INTEGRATION_SETTINGS.HUBSPOT.SAVE_TRANSCRIPTS.TITLE') }}
          </span>
          <span class="text-body-main text-n-slate-11">
            {{ t('INTEGRATION_SETTINGS.HUBSPOT.SAVE_TRANSCRIPTS.DESCRIPTION') }}
          </span>
        </span>
        <Switch v-model="saveTranscripts" data-test="save-transcripts" />
      </label>
    </section>

    <section
      class="flex flex-col gap-4 p-6 outline outline-1 outline-n-container bg-n-card rounded-xl"
    >
      <div class="flex flex-col gap-1">
        <h3 class="m-0 text-heading-3 text-n-slate-12">
          {{ t('INTEGRATION_SETTINGS.HUBSPOT.MAPPING.TITLE') }}
        </h3>
        <p class="m-0 text-body-main text-n-slate-11">
          {{ t('INTEGRATION_SETTINGS.HUBSPOT.MAPPING.DESCRIPTION') }}
        </p>
      </div>
      <div
        v-for="key in rowKeys"
        :key="key"
        class="grid items-center gap-2 sm:grid-cols-[minmax(0,1fr)_minmax(0,2fr)_2rem]"
        :data-test="`mapping-row-${key}`"
      >
        <span class="text-body-main text-n-slate-12 truncate">
          {{ sourceLabels[key] || key }}
        </span>
        <ComboBox
          v-model="mapping[key]"
          :options="propertyOptions"
          :disabled="key === 'email'"
          :placeholder="t('INTEGRATION_SETTINGS.HUBSPOT.MAPPING.NOT_MAPPED')"
          :search-placeholder="t('INTEGRATION_SETTINGS.HUBSPOT.MAPPING.SEARCH')"
          :has-error="duplicateProperties.has(mapping[key])"
          :message="
            duplicateProperties.has(mapping[key])
              ? t('INTEGRATION_SETTINGS.HUBSPOT.MAPPING.DUPLICATE')
              : ''
          "
        />
        <Button
          v-if="!automaticKeys.has(key)"
          type="button"
          icon="i-lucide-trash-2"
          color="slate"
          variant="ghost"
          size="sm"
          :aria-label="t('INTEGRATION_SETTINGS.HUBSPOT.MAPPING.REMOVE')"
          @click="removeRow(key)"
        />
      </div>
      <div v-if="addableSources.length" class="sm:w-1/3">
        <ComboBox
          :key="addPickerKey"
          model-value=""
          :options="addableSources"
          :placeholder="t('INTEGRATION_SETTINGS.HUBSPOT.MAPPING.ADD')"
          :search-placeholder="t('INTEGRATION_SETTINGS.HUBSPOT.MAPPING.SEARCH')"
          data-test="add-mapping"
          @update:model-value="addRow"
        />
      </div>
    </section>

    <div class="flex justify-end">
      <Button
        type="submit"
        :is-loading="isSaving"
        :disabled="duplicateProperties.size > 0"
        :label="t('INTEGRATION_SETTINGS.HUBSPOT.SAVE')"
      />
    </div>
  </form>
</template>

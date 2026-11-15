<script setup>
import { computed, ref } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import LeadMoreOptions from './LeadMoreOptions.vue';
import {
  COMMON_FIELDS,
  KEY_PATTERN,
  MAX_ENTRIES,
  MAX_TEXT_LENGTH,
  RESERVED_KEYS,
  useLeadSettings,
} from './useLeadSettings';

// Step 1 · What to ask: the details to collect and how many questions at most.
// More options: lead types.
const {
  label,
  settings,
  attempted,
  fieldErrorFor,
  fieldError,
  typeErrorFor,
  typeError,
  fieldKeyLocked,
  isFieldSelected,
  togglePresetField,
} = useLeadSettings();

const QUESTION_OPTIONS = [0, 1, 2, 3, 4, 5];
const TYPE_PRESETS = ['ENTERPRISE', 'PARTNERSHIP', 'NEEDS_REVIEW'];

const contactAttributes = useMapGetter('attributes/getContactAttributes');

const slugifyKey = text =>
  (text || '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 40);

const existingAttributeSuggestions = computed(() => {
  const standardSet = new Set([...COMMON_FIELDS, ...RESERVED_KEYS]);
  return (contactAttributes.value || [])
    .map(attr => {
      const rawKey = (attr.attributeKey || '').replace(/^lead_/, '');
      return { key: rawKey, label: attr.attributeDisplayName || rawKey };
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

// Field dialog
const fieldDialogRef = ref(null);
const editingFieldIndex = ref(-1);
const fieldDraft = ref({ key: '', label: '', locked: false });
const fieldDraftAttempted = ref(false);
const fieldDraftError = computed(() =>
  fieldErrorFor(fieldDraft.value, editingFieldIndex.value)
);

const suggestDraftKey = () => {
  if (fieldDraft.value.locked || fieldDraft.value.key) return;
  fieldDraft.value.key = slugifyKey(fieldDraft.value.label);
};

const openFieldDialog = (index = -1) => {
  editingFieldIndex.value = index;
  fieldDraftAttempted.value = false;
  const target = settings.value.lead_fields[index];
  fieldDraft.value = target
    ? { key: target.key, label: target.label, locked: fieldKeyLocked(target) }
    : { key: '', label: '', locked: false };
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

// Lead type dialog
const typeDialogRef = ref(null);
const editingTypeIndex = ref(-1);
const typeDraft = ref({ name: '', rule: '' });
const typeDraftAttempted = ref(false);
const typeDraftError = computed(() =>
  typeErrorFor(typeDraft.value, editingTypeIndex.value)
);

const openTypeDialog = (index = -1) => {
  editingTypeIndex.value = index;
  typeDraftAttempted.value = false;
  const target = settings.value.lead_types[index];
  typeDraft.value = target
    ? { name: target.name, rule: target.rule }
    : { name: '', rule: '' };
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

const typesInvalid = computed(
  () =>
    attempted.value &&
    ((settings.value.leads_enabled && !settings.value.lead_types.length) ||
      settings.value.lead_types.some(typeError))
);
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex flex-col gap-2">
      <div class="flex items-center justify-between gap-3">
        <p class="m-0 text-sm text-n-slate-11">{{ label('FIELDS_HELP') }}</p>
        <span class="shrink-0 text-xs text-n-slate-11">
          {{
            label('SETUP.FIELD_COUNT', {
              count: settings.lead_fields.length,
              max: MAX_ENTRIES,
            })
          }}
        </span>
      </div>
      <div class="flex flex-wrap gap-2">
        <span
          class="inline-flex items-center gap-1.5 rounded-xl bg-n-alpha-2 px-3 py-1.5 text-sm font-medium text-n-slate-11"
        >
          <span class="i-lucide-check size-3.5 text-n-teal-10" />
          {{ label('ALWAYS_NAME_EMAIL') }}
        </span>
        <button
          v-for="key in COMMON_FIELDS"
          :key="key"
          type="button"
          :aria-pressed="isFieldSelected(key)"
          class="inline-flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-sm font-medium transition-colors"
          :class="
            isFieldSelected(key)
              ? 'bg-n-blue-3 text-n-blue-11 outline outline-1 outline-n-blue-8'
              : 'bg-n-solid-1 text-n-slate-12 outline outline-1 outline-n-weak hover:outline-n-strong'
          "
          @click="togglePresetField(key, label(`COMMON_FIELDS.${key}`))"
        >
          <span
            :class="isFieldSelected(key) ? 'i-lucide-check' : 'i-lucide-plus'"
            class="size-3.5"
          />
          {{ label(`COMMON_FIELDS.${key}`) }}
        </button>
        <button
          v-for="field in customFieldChips"
          :key="field.key || field.label"
          type="button"
          :aria-invalid="attempted && !!fieldError(field)"
          class="inline-flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-sm font-medium transition-colors"
          :class="
            attempted && fieldError(field)
              ? 'bg-n-ruby-3 text-n-ruby-11 outline outline-1 outline-n-ruby-8'
              : 'bg-n-blue-3 text-n-blue-11 outline outline-1 outline-n-blue-8'
          "
          @click="openFieldDialog(settings.lead_fields.indexOf(field))"
        >
          <span class="i-lucide-pencil size-3" />
          {{ field.label || field.key }}
        </button>
        <button
          v-for="attr in existingAttributeSuggestions"
          :key="attr.key"
          type="button"
          class="inline-flex items-center gap-1.5 rounded-xl bg-n-solid-1 px-3 py-1.5 text-sm font-medium text-n-slate-11 outline outline-1 outline-n-weak hover:text-n-slate-12 hover:outline-n-strong"
          @click="togglePresetField(attr.key, attr.label)"
        >
          <span class="i-lucide-plus size-3.5" />
          {{ attr.label }}
        </button>
        <button
          v-if="settings.lead_fields.length < MAX_ENTRIES"
          type="button"
          class="inline-flex items-center gap-1.5 rounded-xl border border-dashed border-n-strong bg-transparent px-3 py-1.5 text-sm font-medium text-n-slate-11 hover:border-n-brand hover:text-n-slate-12"
          @click="openFieldDialog(-1)"
        >
          <span class="i-lucide-plus size-3.5" />
          {{ label('ADD_FIELD') }}
        </button>
      </div>
      <p class="m-0 text-xs text-n-slate-11">
        {{ label('GUIDED.LOCATION_HELP') }}
      </p>
    </div>

    <div
      class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between"
    >
      <div class="flex flex-col gap-0.5">
        <span class="text-sm font-medium text-n-slate-12">
          {{ label('MAX_QUESTIONS') }}
        </span>
        <span class="text-xs text-n-slate-11">
          {{ label('QUESTIONS_HELP') }}
        </span>
      </div>
      <div
        class="flex shrink-0 self-start rounded-xl bg-n-alpha-2 p-1"
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

    <LeadMoreOptions :open="typesInvalid">
      <div class="flex items-start justify-between gap-3">
        <div class="flex flex-col gap-0.5">
          <span class="text-sm font-medium text-n-slate-12">
            {{ label('TYPES') }}
          </span>
          <span class="text-xs text-n-slate-11">{{ label('TYPES_HELP') }}</span>
        </div>
        <Button
          v-if="settings.lead_types.length < MAX_ENTRIES"
          type="button"
          variant="faded"
          color="slate"
          size="xs"
          icon="i-lucide-plus"
          :label="label('ADD_TYPE')"
          @click="openTypeDialog(-1)"
        />
      </div>
      <div
        v-if="settings.lead_types.length"
        class="-mx-2 flex flex-col divide-y divide-n-weak"
      >
        <button
          v-for="(type, index) in settings.lead_types"
          :key="index"
          type="button"
          :aria-invalid="attempted && !!typeError(type)"
          class="flex min-w-0 flex-col items-start gap-0.5 rounded-xl px-2.5 py-2 text-start hover:bg-n-alpha-1"
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
    </LeadMoreOptions>

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
        <div>
          <p class="text-xs font-medium text-n-slate-11">
            {{ label('GUIDED.ATTRIBUTE_SETTINGS') }}
          </p>
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
        </div>
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
            <span
              class="i-lucide-plus me-1 inline-block size-3"
              aria-hidden="true"
            />
            {{ label(`TYPE_PRESETS.${preset}.LABEL`) }}
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
        <p class="m-0 text-xs text-n-slate-11">{{ label('FALLBACK_HELP') }}</p>
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
  </div>
</template>

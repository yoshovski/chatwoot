<script setup>
import { computed, nextTick, ref, toRaw, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
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
const { t, n } = useI18n();
const router = useRouter();
const label = (key, params = {}) =>
  t(`CAPTAIN.ASSISTANTS.SETTINGS.LEADS.${key}`, params);
const MAX_ENTRIES = 10;
const MAX_QUESTIONS = 5;
const MAX_TEXT_LENGTH = 300;
const KEY_PATTERN = /^[a-z][a-z0-9_]{0,39}$/;
const RESERVED_KEYS = ['type', 'summary', 'source', 'status'];
const COMMON_FIELDS = ['company', 'country', 'audience_size', 'use_case'];
const settings = ref({});
const savedSnapshot = ref('');
const saving = ref(false);
const attempted = ref(false);
const form = ref(null);
const setup = useLeadSetup(computed(() => props.assistant.id));
const { captureScenario, hubspotState, loading, scenarioError } = setup;
const snapshot = () => JSON.stringify(settings.value);
const isDirty = computed(() => snapshot() !== savedSnapshot.value);
let lockedFields = new WeakSet();
const fieldKeyLocked = field => lockedFields.has(toRaw(field));

const reset = () => {
  const config = props.assistant.config || {};
  settings.value = {
    leads_enabled: config.leads_enabled === true,
    lead_max_questions: config.lead_max_questions ?? 2,
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
  if (value && !settings.value.lead_types.length) {
    settings.value.lead_types.push({
      name: 'business_inquiry',
      rule: label('DEFAULT_TYPE_RULE'),
    });
  }
};
const availableFields = computed(() =>
  COMMON_FIELDS.filter(
    key => !settings.value.lead_fields.some(field => field.key === key)
  )
);
const addField = key =>
  settings.value.lead_fields.push({
    key: key || '',
    label: key ? label(`COMMON_FIELDS.${key}`) : '',
  });
const suggestKey = field => {
  if (field.key) return;
  field.key = field.label
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 40);
};
const fieldError = field => {
  if (!KEY_PATTERN.test(field.key) || RESERVED_KEYS.includes(field.key))
    return label('ERRORS.KEY');
  if (
    settings.value.lead_fields.filter(item => item.key === field.key).length > 1
  )
    return label('ERRORS.DUPLICATE_KEY');
  if (!field.label.trim() || field.label.length > MAX_TEXT_LENGTH)
    return label('ERRORS.FIELD');
  return '';
};
const typeError = type => {
  if (
    !type.name.trim() ||
    !type.rule.trim() ||
    type.name.length > MAX_TEXT_LENGTH ||
    type.rule.length > MAX_TEXT_LENGTH
  )
    return label('ERRORS.TYPE');
  if (
    settings.value.lead_types.filter(
      item => item.name.trim() === type.name.trim()
    ).length > 1
  )
    return label('ERRORS.DUPLICATE_TYPE');
  return '';
};
const hasErrors = computed(
  () =>
    (settings.value.leads_enabled && !settings.value.lead_types.length) ||
    settings.value.lead_fields.some(fieldError) ||
    settings.value.lead_types.some(typeError)
);
const changeQuestions = delta => {
  settings.value.lead_max_questions = Math.max(
    0,
    Math.min(MAX_QUESTIONS, settings.value.lead_max_questions + delta)
  );
};
const save = async () => {
  attempted.value = true;
  if (hasErrors.value) {
    await nextTick();
    form.value?.querySelector('[aria-invalid="true"]')?.focus();
    return false;
  }
  saving.value = true;
  try {
    const result = await props.save({ config: JSON.parse(snapshot()) });
    if (result === false) return false;
    savedSnapshot.value = snapshot();
    attempted.value = false;
    return true;
  } finally {
    saving.value = false;
  }
};
const openScenarios = async () => {
  if (isDirty.value && !(await save())) return;
  router.push({
    name: 'captain_assistants_scenarios_index',
    params: { assistantId: props.assistant.id },
    query: captureScenario.value ? {} : { template: 'capture_business_lead' },
  });
};
const hubspotLabel = computed(() =>
  label(`HUBSPOT.${hubspotState.value.toUpperCase()}`)
);
const statusLabel = computed(() => {
  if (isDirty.value) return label('STATUS.UNSAVED');
  if (!settings.value.leads_enabled) return label('STATUS.OFF');
  if (loading.value) return label('STATUS.CHECKING');
  if (scenarioError.value) return label('STATUS.UNKNOWN');
  return label(
    captureScenario.value ? 'STATUS.READY' : 'STATUS.NEEDS_SCENARIO'
  );
});
</script>

<template>
  <form ref="form" class="flex flex-col gap-6" @submit.prevent="save">
    <section
      class="rounded-xl bg-n-solid-1 px-5 py-1 outline outline-1 outline-n-weak"
    >
      <SettingsSwitchRow
        :model-value="settings.leads_enabled"
        :title="label('ENABLE')"
        :description="label('ENABLE_DESCRIPTION')"
        @update:model-value="enableCapture"
      >
        <span
          class="mt-2 flex items-center gap-1.5 text-xs text-n-slate-11"
          role="status"
        >
          <span
            class="size-1.5 rounded-full"
            :class="
              !isDirty && settings.leads_enabled && captureScenario
                ? 'bg-n-teal-9'
                : 'bg-n-slate-8'
            "
            aria-hidden="true"
          />
          {{ statusLabel }}
        </span>
      </SettingsSwitchRow>
    </section>

    <SettingsSplit>
      <div class="flex flex-col gap-6">
        <section
          class="flex flex-col gap-4 rounded-xl bg-n-solid-1 p-5 outline outline-1 outline-n-weak"
        >
          <div class="flex items-start gap-3">
            <span
              class="flex size-7 shrink-0 items-center justify-center rounded-full bg-n-blue-3 text-sm font-medium text-n-blue-11"
              aria-hidden="true"
              >{{ n(1) }}</span
            >
            <div>
              <h3 class="m-0 text-base font-semibold text-n-slate-12">
                {{ label('FIELDS') }}
              </h3>
              <p class="mb-0 mt-1 text-sm text-n-slate-11">
                {{ label('FIELDS_HELP') }}
              </p>
            </div>
          </div>
          <div
            class="rounded-lg bg-n-slate-2 px-3 py-2.5 text-sm text-n-slate-11"
          >
            {{ label('INCLUDED') }}
          </div>
          <div
            v-for="(field, index) in settings.lead_fields"
            :key="index"
            class="flex flex-col gap-2 rounded-lg outline outline-1 outline-n-weak p-3"
          >
            <div class="flex items-start gap-2">
              <Input
                v-model="field.label"
                class="min-w-0 flex-1"
                :label="label('FIELD_LABEL')"
                :maxlength="MAX_TEXT_LENGTH"
                :placeholder="label('FIELD_PLACEHOLDER')"
                :aria-invalid="attempted && !!fieldError(field)"
                @blur="suggestKey(field)"
              />
              <Button
                type="button"
                variant="ghost"
                color="slate"
                icon="i-lucide-trash-2"
                class="mt-6"
                :aria-label="
                  label('REMOVE_FIELD', {
                    name: field.label || label('FIELD_LABEL'),
                  })
                "
                @click="settings.lead_fields.splice(index, 1)"
              />
            </div>
            <details
              :open="attempted && !!fieldError(field)"
              class="text-xs text-n-slate-11"
            >
              <summary class="cursor-pointer">
                {{ label('FIELD_KEY') }}
                <code v-if="field.key" class="ms-1">{{ field.key }}</code>
              </summary>
              <Input
                v-model="field.key"
                class="mt-2"
                :label="label('FIELD_KEY')"
                :disabled="fieldKeyLocked(field)"
                :maxlength="40"
                :placeholder="label('KEY_PLACEHOLDER')"
                :aria-invalid="attempted && !!fieldError(field)"
              />
              <p class="mb-0 mt-2">
                {{ label(fieldKeyLocked(field) ? 'KEY_LOCKED' : 'KEY_HELP') }}
              </p>
            </details>
            <p
              v-if="attempted && fieldError(field)"
              class="m-0 text-xs text-n-ruby-11"
              role="alert"
            >
              {{ fieldError(field) }}
            </p>
          </div>
          <p
            v-if="!settings.lead_fields.length"
            class="m-0 text-sm text-n-slate-11"
          >
            {{ label('NO_FIELDS') }}
          </p>
          <div
            v-if="settings.lead_fields.length < MAX_ENTRIES"
            class="flex flex-wrap gap-2"
          >
            <Button
              v-for="key in availableFields"
              :key="key"
              type="button"
              size="sm"
              variant="faded"
              color="slate"
              icon="i-lucide-plus"
              :label="label(`COMMON_FIELDS.${key}`)"
              @click="addField(key)"
            />
            <Button
              type="button"
              size="sm"
              variant="ghost"
              icon="i-lucide-plus"
              :label="label('ADD_FIELD')"
              @click="addField()"
            />
          </div>
          <p v-else class="m-0 text-xs text-n-slate-11">
            {{ label('LIMIT', { count: MAX_ENTRIES }) }}
          </p>
        </section>

        <section
          class="flex flex-col gap-4 rounded-xl bg-n-solid-1 p-5 outline outline-1 outline-n-weak"
        >
          <div class="flex items-start gap-3">
            <span
              class="flex size-7 shrink-0 items-center justify-center rounded-full bg-n-blue-3 text-sm font-medium text-n-blue-11"
              aria-hidden="true"
              >{{ n(2) }}</span
            >
            <div>
              <h3 class="m-0 text-base font-semibold text-n-slate-12">
                {{ label('TYPES') }}
              </h3>
              <p class="mb-0 mt-1 text-sm text-n-slate-11">
                {{ label('TYPES_HELP') }}
              </p>
            </div>
          </div>
          <div
            v-for="(type, index) in settings.lead_types"
            :key="index"
            class="flex flex-col gap-3 rounded-lg outline outline-1 outline-n-weak p-3"
          >
            <div class="flex items-start gap-2">
              <Input
                v-model="type.name"
                class="min-w-0 flex-1"
                :label="label('TYPE_NAME')"
                :maxlength="MAX_TEXT_LENGTH"
                :placeholder="label('TYPE_PLACEHOLDER')"
                :aria-invalid="attempted && !!typeError(type)"
              />
              <Button
                type="button"
                variant="ghost"
                color="slate"
                icon="i-lucide-trash-2"
                class="mt-6"
                :aria-label="
                  label('REMOVE_TYPE', {
                    name: type.name || label('TYPE_NAME'),
                  })
                "
                @click="settings.lead_types.splice(index, 1)"
              />
            </div>
            <label
              class="m-0 flex flex-col gap-1.5 text-sm font-medium text-n-slate-12"
            >
              {{ label('TYPE_RULE') }}
              <textarea
                v-model="type.rule"
                rows="3"
                :maxlength="MAX_TEXT_LENGTH"
                :placeholder="label('RULE_PLACEHOLDER')"
                :aria-invalid="attempted && !!typeError(type)"
                class="m-0 w-full resize-y rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-sm font-normal text-n-slate-12 placeholder:text-n-slate-10 focus:border-n-brand focus:outline-none"
              />
            </label>
            <p
              v-if="attempted && typeError(type)"
              class="m-0 text-xs text-n-ruby-11"
              role="alert"
            >
              {{ typeError(type) }}
            </p>
          </div>
          <p
            v-if="!settings.lead_types.length"
            class="m-0 text-sm"
            :class="
              attempted && settings.leads_enabled
                ? 'text-n-ruby-11'
                : 'text-n-slate-11'
            "
          >
            {{ label('NO_TYPES') }}
          </p>
          <Button
            v-if="settings.lead_types.length < MAX_ENTRIES"
            type="button"
            class="self-start"
            variant="faded"
            size="sm"
            icon="i-lucide-plus"
            :label="label('ADD_TYPE')"
            @click="settings.lead_types.push({ name: '', rule: '' })"
          />
          <p class="m-0 text-xs text-n-slate-11">
            {{ label('FALLBACK_HELP') }}
          </p>
        </section>

        <section
          class="flex flex-col gap-4 rounded-xl bg-n-solid-1 p-5 outline outline-1 outline-n-weak"
        >
          <div class="flex items-start gap-3">
            <span
              class="flex size-7 shrink-0 items-center justify-center rounded-full bg-n-blue-3 text-sm font-medium text-n-blue-11"
              aria-hidden="true"
              >{{ n(3) }}</span
            >
            <div>
              <h3 class="m-0 text-base font-semibold text-n-slate-12">
                {{ label('CONVERSATION') }}
              </h3>
              <p class="mb-0 mt-1 text-sm text-n-slate-11">
                {{ label('CONVERSATION_HELP') }}
              </p>
            </div>
          </div>
          <div class="flex items-center justify-between gap-3">
            <div class="text-sm text-n-slate-12">
              {{ label('MAX_QUESTIONS') }}
              <p class="mb-0 mt-1 text-xs text-n-slate-11">
                {{ label('QUESTIONS_HELP') }}
              </p>
            </div>
            <div class="flex shrink-0 items-center gap-2">
              <Button
                type="button"
                size="sm"
                variant="faded"
                color="slate"
                icon="i-lucide-minus"
                :disabled="settings.lead_max_questions === 0"
                :aria-label="label('FEWER_QUESTIONS')"
                @click="changeQuestions(-1)"
              />
              <output
                class="w-5 text-center text-sm font-medium text-n-slate-12"
                aria-live="polite"
                >{{ settings.lead_max_questions }}</output
              >
              <Button
                type="button"
                size="sm"
                variant="faded"
                color="slate"
                icon="i-lucide-plus"
                :disabled="settings.lead_max_questions === MAX_QUESTIONS"
                :aria-label="label('MORE_QUESTIONS')"
                @click="changeQuestions(1)"
              />
            </div>
          </div>
          <div class="flex flex-col gap-2 border-t border-n-weak pt-4">
            <span class="text-sm font-medium text-n-slate-12">{{
              label('SCENARIO_TITLE')
            }}</span>
            <p class="m-0 text-sm text-n-slate-11">
              {{
                loading
                  ? label('STATUS.CHECKING')
                  : scenarioError
                    ? label('SCENARIO_ERROR')
                    : captureScenario
                      ? label('SCENARIO_FOUND', { name: captureScenario.title })
                      : label('SCENARIO_MISSING')
              }}
            </p>
            <Button
              type="button"
              class="self-start"
              size="sm"
              variant="faded"
              icon="i-lucide-git-branch"
              :disabled="!settings.leads_enabled || loading || scenarioError"
              :is-loading="saving"
              :label="
                label(
                  captureScenario
                    ? 'MANAGE_SCENARIO'
                    : isDirty
                      ? 'SAVE_ADD_SCENARIO'
                      : 'ADD_SCENARIO'
                )
              "
              @click="openScenarios"
            />
          </div>
        </section>

        <section
          class="flex flex-col gap-3 rounded-xl bg-n-solid-1 p-5 outline outline-1 outline-n-weak"
        >
          <h3 class="m-0 text-base font-semibold text-n-slate-12">
            {{ label('FOLLOW_UP') }}
          </h3>
          <p class="m-0 text-sm text-n-slate-11">
            {{ label('FOLLOW_UP_HELP') }}
          </p>
          <div
            class="flex flex-wrap items-center justify-between gap-3 rounded-lg bg-n-slate-2 p-3"
          >
            <div class="flex flex-col gap-1">
              <span class="text-sm font-medium text-n-slate-12">{{
                label('HUBSPOT_TITLE')
              }}</span>
              <span class="text-xs text-n-slate-11" role="status">{{
                hubspotLabel
              }}</span>
            </div>
            <Button
              v-if="canManageIntegrations"
              type="button"
              variant="link"
              size="sm"
              :label="label('HUBSPOT_ACTION')"
              @click="router.push({ name: 'settings_integrations_hubspot' })"
            />
          </div>
          <p class="m-0 text-xs text-n-slate-11">{{ label('VERIFICATION') }}</p>
          <Button
            type="button"
            class="self-start"
            variant="ghost"
            color="slate"
            size="sm"
            icon="i-lucide-refresh-cw"
            :label="label('REFRESH')"
            :is-loading="loading"
            @click="setup.refresh"
          />
        </section>
      </div>
      <template #preview>
        <LeadCapturePreview
          :enabled="settings.leads_enabled"
          :fields="settings.lead_fields"
          :types="settings.lead_types"
          :max-questions="settings.lead_max_questions"
        />
      </template>
    </SettingsSplit>
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
  </form>
</template>

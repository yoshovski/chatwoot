<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const props = defineProps({
  assistant: { type: Object, required: true },
  save: { type: Function, required: true },
});
const { t } = useI18n();
const router = useRouter();
const settings = ref({});
const saving = ref(false);
watch(
  () => props.assistant.config,
  config => {
    settings.value = {
      leads_enabled: config?.leads_enabled === true,
      lead_max_questions: config?.lead_max_questions ?? 2,
      lead_fields: (config?.lead_fields || []).map(field => ({ ...field })),
      lead_types: (config?.lead_types || []).map(type => ({ ...type })),
    };
  },
  { immediate: true, deep: true }
);
const save = async () => {
  saving.value = true;
  try {
    await props.save({ config: settings.value });
  } finally {
    saving.value = false;
  }
};
const openScenarios = () =>
  router.push({
    name: 'captain_assistants_scenarios_index',
    params: { assistantId: props.assistant.id },
    query: { template: 'capture_business_lead' },
  });
</script>

<template>
  <form
    class="flex flex-col gap-4 rounded-xl border border-n-weak p-5"
    @submit.prevent="save"
  >
    <h2 class="text-heading-2 m-0">
      {{ t('CAPTAIN.ASSISTANTS.SETTINGS.LEADS.TITLE') }}
    </h2>
    <p class="text-sm text-n-slate-11 m-0">
      {{ t('CAPTAIN.ASSISTANTS.SETTINGS.LEADS.DESCRIPTION') }}
    </p>
    <label class="flex items-center gap-2 text-sm text-n-slate-12">
      <input v-model="settings.leads_enabled" type="checkbox" />
      {{ t('CAPTAIN.ASSISTANTS.SETTINGS.LEADS.ENABLE') }}
    </label>
    <template v-if="settings.leads_enabled">
      <p class="text-sm text-n-slate-11 m-0">
        {{ t('CAPTAIN.ASSISTANTS.SETTINGS.LEADS.VERIFICATION') }}
      </p>
      <Input
        v-model.number="settings.lead_max_questions"
        type="number"
        min="0"
        max="5"
        :label="t('CAPTAIN.ASSISTANTS.SETTINGS.LEADS.MAX_QUESTIONS')"
      />
      <h3 class="text-sm font-medium m-0">
        {{ t('CAPTAIN.ASSISTANTS.SETTINGS.LEADS.FIELDS') }}
      </h3>
      <p class="text-sm text-n-slate-11 m-0">
        {{ t('CAPTAIN.ASSISTANTS.SETTINGS.LEADS.FIELDS_HELP') }}
      </p>
      <div
        v-for="(field, index) in settings.lead_fields"
        :key="index"
        class="grid gap-2 sm:grid-cols-[1fr_1fr_auto] items-end"
      >
        <Input
          v-model="field.key"
          :label="t('CAPTAIN.ASSISTANTS.SETTINGS.LEADS.FIELD_KEY')"
          required
          pattern="[a-z][a-z0-9_]{0,39}"
        />
        <Input
          v-model="field.label"
          :label="t('CAPTAIN.ASSISTANTS.SETTINGS.LEADS.FIELD_LABEL')"
          required
          :maxlength="300"
        />
        <Button
          type="button"
          variant="ghost"
          icon="i-lucide-trash-2"
          :label="t('CAPTAIN.ASSISTANTS.SETTINGS.LEADS.REMOVE')"
          @click="settings.lead_fields.splice(index, 1)"
        />
      </div>
      <Button
        v-if="settings.lead_fields.length < 10"
        type="button"
        variant="faded"
        :label="t('CAPTAIN.ASSISTANTS.SETTINGS.LEADS.ADD_FIELD')"
        @click="settings.lead_fields.push({ key: '', label: '' })"
      />
      <h3 class="text-sm font-medium m-0">
        {{ t('CAPTAIN.ASSISTANTS.SETTINGS.LEADS.TYPES') }}
      </h3>
      <div
        v-for="(type, index) in settings.lead_types"
        :key="index"
        class="grid gap-2 sm:grid-cols-[1fr_2fr_auto] items-end"
      >
        <Input
          v-model="type.name"
          :label="t('CAPTAIN.ASSISTANTS.SETTINGS.LEADS.TYPE_NAME')"
          required
          :maxlength="300"
        />
        <Input
          v-model="type.rule"
          :label="t('CAPTAIN.ASSISTANTS.SETTINGS.LEADS.TYPE_RULE')"
          required
          :maxlength="300"
        />
        <Button
          type="button"
          variant="ghost"
          icon="i-lucide-trash-2"
          :label="t('CAPTAIN.ASSISTANTS.SETTINGS.LEADS.REMOVE')"
          @click="settings.lead_types.splice(index, 1)"
        />
      </div>
      <Button
        v-if="settings.lead_types.length < 10"
        type="button"
        variant="faded"
        :label="t('CAPTAIN.ASSISTANTS.SETTINGS.LEADS.ADD_TYPE')"
        @click="settings.lead_types.push({ name: '', rule: '' })"
      />
      <p class="text-sm text-n-slate-11 m-0">
        {{ t('CAPTAIN.ASSISTANTS.SETTINGS.LEADS.SCENARIO_HELP') }}
      </p>
      <Button
        type="button"
        variant="faded"
        :label="t('CAPTAIN.ASSISTANTS.SETTINGS.LEADS.SCENARIO')"
        @click="openScenarios"
      />
    </template>
    <div class="flex justify-end">
      <Button
        type="submit"
        :is-loading="saving"
        :label="t('CAPTAIN.ASSISTANTS.SETTINGS.LEADS.SAVE')"
      />
    </div>
  </form>
</template>

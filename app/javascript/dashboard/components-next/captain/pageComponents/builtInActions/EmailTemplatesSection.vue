<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import SidePanel from 'dashboard/components-next/side-panel/SidePanel.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';

// The AI agent's email templates, used by "Email the visitor", "Email the team" and email follow-ups.
// Stored in the agent's config as { key: { name, subject, body } }.
const { t } = useI18n();
const store = useStore();
const route = useRoute();

const MAX_TEMPLATES = 10;
const SUBJECT_LIMIT = 200;
const BODY_LIMIT = 5000;
const VARIABLES = [
  'contact.first_name',
  'contact.name',
  'contact.email',
  'conversation.display_id',
  'agent.name',
  'summary',
];
// Sample values for the preview; invented, never real customer data.
const PREVIEW_VALUES = {
  'contact.first_name': 'Jamie',
  'contact.name': 'Jamie Rivera',
  'contact.email': 'jamie@harbor-bikes.test',
  'conversation.display_id': '42',
  'agent.name': 'Ada',
  summary: 'Wants a demo for a team of 40.',
};

const assistantId = computed(() => Number(route.params.assistantId));
const assistant = computed(() =>
  store.getters['captainAssistants/getRecord'](assistantId.value)
);
const templates = computed(
  () => assistant.value?.config?.email_templates || {}
);
const templateList = computed(() =>
  Object.entries(templates.value).map(([key, template]) => ({
    key,
    ...template,
  }))
);
const canAdd = computed(() => templateList.value.length < MAX_TEMPLATES);

const panelRef = ref(null);
const editingKey = ref(null);
const isSaving = ref(false);
const bodyField = ref('body');
const form = reactive({ name: '', key: '', subject: '', body: '' });

const slugify = name =>
  name
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 40);

const onName = value => {
  form.name = value;
  if (!editingKey.value) form.key = slugify(value);
};

const open = (template = null) => {
  editingKey.value = template?.key || null;
  Object.assign(form, {
    name: template?.name || '',
    key: template?.key || '',
    subject: template?.subject || '',
    body: template?.body || '',
  });
  panelRef.value?.open();
};

const insertVariable = variable => {
  form[bodyField.value] = `${form[bodyField.value]}{{ ${variable} }}`;
};

const preview = text =>
  text.replace(
    /\{\{\s*([a-z_.]+)\s*\}\}/g,
    (match, name) => PREVIEW_VALUES[name] ?? ''
  );

const isValid = computed(
  () =>
    /^[a-z0-9_]{1,40}$/.test(form.key) &&
    form.subject.trim() &&
    form.body.trim() &&
    (editingKey.value || !templates.value[form.key])
);

const save = async nextTemplates => {
  isSaving.value = true;
  try {
    await store.dispatch('captainAssistants/update', {
      id: assistantId.value,
      config: { email_templates: nextTemplates },
    });
    return true;
  } catch (error) {
    useAlert(error?.message || t('CAPTAIN.EMAIL_TEMPLATES.ERROR'));
    return false;
  } finally {
    isSaving.value = false;
  }
};

const submit = async () => {
  if (!isValid.value) return;
  const next = { ...templates.value };
  if (editingKey.value && editingKey.value !== form.key) {
    delete next[editingKey.value];
  }
  next[form.key] = {
    name: form.name.trim(),
    subject: form.subject.trim(),
    body: form.body.trim(),
  };
  if (await save(next)) {
    useAlert(t('CAPTAIN.EMAIL_TEMPLATES.SAVED'));
    panelRef.value?.close();
  }
};

const remove = async key => {
  const next = { ...templates.value };
  delete next[key];
  await save(next);
};

defineExpose({ open });
</script>

<template>
  <section class="flex flex-col gap-3" data-test="email-templates">
    <div class="flex items-center justify-between gap-2">
      <div class="flex flex-col gap-0.5">
        <h2 class="mb-0 text-sm font-medium text-n-slate-12">
          {{ t('CAPTAIN.EMAIL_TEMPLATES.TITLE') }}
        </h2>
        <p class="mb-0 text-sm text-n-slate-11">
          {{ t('CAPTAIN.EMAIL_TEMPLATES.DESCRIPTION') }}
        </p>
      </div>
      <Button
        sm
        faded
        slate
        icon="i-lucide-plus"
        :label="t('CAPTAIN.EMAIL_TEMPLATES.ADD')"
        :disabled="!canAdd"
        data-test="email-template-add"
        @click="open()"
      />
    </div>

    <p
      v-if="!templateList.length"
      class="mb-0 text-sm text-n-slate-10"
      data-test="email-templates-empty"
    >
      {{ t('CAPTAIN.EMAIL_TEMPLATES.EMPTY') }}
    </p>
    <div
      v-for="template in templateList"
      :key="template.key"
      class="flex items-center justify-between gap-3 px-3 py-2 border rounded-lg border-n-weak"
      data-test="email-template-row"
    >
      <div class="flex flex-col min-w-0">
        <span class="text-sm font-medium truncate text-n-slate-12">
          {{ template.name || template.key }}
        </span>
        <span class="text-xs truncate text-n-slate-11">
          {{ template.subject }}
        </span>
      </div>
      <div class="flex gap-1 shrink-0">
        <Button
          xs
          ghost
          slate
          icon="i-lucide-pencil"
          :aria-label="t('CAPTAIN.EMAIL_TEMPLATES.EDIT')"
          @click="open(template)"
        />
        <Button
          xs
          ghost
          ruby
          icon="i-lucide-trash-2"
          :aria-label="t('CAPTAIN.EMAIL_TEMPLATES.DELETE')"
          :disabled="isSaving"
          @click="remove(template.key)"
        />
      </div>
    </div>

    <SidePanel
      ref="panelRef"
      :title="
        editingKey
          ? t('CAPTAIN.EMAIL_TEMPLATES.EDIT')
          : t('CAPTAIN.EMAIL_TEMPLATES.ADD')
      "
    >
      <div class="flex flex-col gap-4" data-test="email-template-form">
        <Input
          :model-value="form.name"
          :label="t('CAPTAIN.EMAIL_TEMPLATES.FIELDS.NAME')"
          :placeholder="t('CAPTAIN.EMAIL_TEMPLATES.FIELDS.NAME_PLACEHOLDER')"
          @update:model-value="onName"
        />
        <Input
          v-model="form.key"
          :label="t('CAPTAIN.EMAIL_TEMPLATES.FIELDS.KEY')"
          :message="t('CAPTAIN.EMAIL_TEMPLATES.FIELDS.KEY_HELP')"
        />
        <Input
          v-model="form.subject"
          :label="t('CAPTAIN.EMAIL_TEMPLATES.FIELDS.SUBJECT')"
          :max-length="SUBJECT_LIMIT"
          @focus="bodyField = 'subject'"
        />
        <TextArea
          v-model="form.body"
          :label="t('CAPTAIN.EMAIL_TEMPLATES.FIELDS.BODY')"
          :max-length="BODY_LIMIT"
          auto-height
          @focus="bodyField = 'body'"
        />
        <div class="flex flex-wrap items-center gap-1.5">
          <span class="text-xs font-medium text-n-slate-11">
            {{ t('CAPTAIN.EMAIL_TEMPLATES.VARIABLES') }}
          </span>
          <Button
            v-for="variable in VARIABLES"
            :key="variable"
            type="button"
            xs
            faded
            slate
            :label="variable"
            @click="insertVariable(variable)"
          />
        </div>
        <div
          class="flex flex-col gap-1 p-3 rounded-lg bg-n-alpha-1"
          data-test="email-template-preview"
        >
          <span class="text-xs font-medium text-n-slate-11">
            {{ t('CAPTAIN.EMAIL_TEMPLATES.PREVIEW') }}
          </span>
          <span class="text-sm font-medium text-n-slate-12">
            {{ preview(form.subject) }}
          </span>
          <p class="mb-0 text-sm whitespace-pre-line text-n-slate-12">
            {{ preview(form.body) }}
          </p>
        </div>
      </div>
      <template #footer>
        <div class="flex justify-end gap-2">
          <Button
            :label="t('CAPTAIN.EMAIL_TEMPLATES.SAVE')"
            :disabled="!isValid"
            :is-loading="isSaving"
            data-test="email-template-save"
            @click="submit"
          />
        </div>
      </template>
    </SidePanel>
  </section>
</template>

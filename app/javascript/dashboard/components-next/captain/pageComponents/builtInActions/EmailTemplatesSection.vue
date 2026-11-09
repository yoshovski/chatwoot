<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import SidePanel from 'dashboard/components-next/side-panel/SidePanel.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SegmentedChoice from 'dashboard/components-next/captain/pageComponents/assistant/settings/SegmentedChoice.vue';
import VariableEditor from './VariableEditor.vue';

// The AI agent's email templates, used by "Email the visitor", "Email the team" and email follow-ups.
// Stored in the agent's config as { key: { name, subject, body, format } }; the key is made from the name.
const { t } = useI18n();
const store = useStore();
const route = useRoute();
const contactAttributes = useMapGetter('attributes/getContactAttributes');

const MAX_TEMPLATES = 10;
const V = 'CAPTAIN.AGENT_UX.EMAIL';

// Variables the server fills in (Captain::EmailTemplates#assigns_for), with invented sample values for the preview.
const BASE_VARIABLES = [
  { key: 'contact.first_name', group: 'CUSTOMER', sample: 'Jamie' },
  { key: 'contact.last_name', group: 'CUSTOMER', sample: 'Rivera' },
  { key: 'contact.name', group: 'CUSTOMER', sample: 'Jamie Rivera' },
  { key: 'contact.email', group: 'CUSTOMER', sample: 'jamie@example.test' },
  { key: 'contact.phone_number', group: 'CUSTOMER', sample: '+34 600 000 000' },
  { key: 'conversation.display_id', group: 'CHAT', sample: '1042' },
  {
    key: 'conversation_url',
    group: 'CHAT',
    sample: 'https://app.example.test/conversations/1042',
  },
  {
    key: 'summary',
    group: 'CHAT',
    sample: 'Asked where order 1042 is. It ships tomorrow.',
  },
  { key: 'assignee.name', group: 'CHAT', sample: 'Maria Lopez' },
  { key: 'inbox.name', group: 'CHAT', sample: 'Website chat' },
  { key: 'business.name', group: 'BUSINESS', sample: 'Northwind Outdoor' },
  { key: 'agent.name', group: 'BUSINESS', sample: '' },
  { key: 'today', group: 'BUSINESS', sample: '9 November 2026' },
];
const GROUPS = ['CUSTOMER', 'CHAT', 'BUSINESS'];

const assistantId = computed(() => Number(route.params.assistantId));
const assistant = computed(() =>
  store.getters['captainAssistants/getRecord'](assistantId.value)
);
const agentName = computed(() => assistant.value?.name || '');

const variables = computed(() => [
  ...BASE_VARIABLES.map(variable => ({
    ...variable,
    label: t(
      `${V}.VARIABLES.${variable.key.replace(/\./g, '_').toUpperCase()}`
    ),
    groupLabel: t(`${V}.GROUPS.${variable.group}`),
    sample: variable.key === 'agent.name' ? agentName.value : variable.sample,
  })),
  ...(contactAttributes.value || []).map(attribute => ({
    key: `contact.custom_attribute.${attribute.attributeKey}`,
    group: 'CUSTOMER',
    label: attribute.attributeDisplayName,
    groupLabel: t(`${V}.GROUPS.CUSTOMER`),
    sample: t(`${V}.SAMPLE_VALUE`, { name: attribute.attributeDisplayName }),
  })),
]);
const editorVariables = computed(() =>
  variables.value.map(variable => ({
    key: variable.key,
    label: variable.label,
    group: variable.groupLabel,
  }))
);
const groupedVariables = computed(() =>
  GROUPS.map(group => ({
    group,
    items: variables.value.filter(variable => variable.group === group),
  }))
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

const panelRef = ref(null);
const subjectEditor = ref(null);
const bodyEditor = ref(null);
const lastEditor = ref('body');
const editingKey = ref(null);
const isSaving = ref(false);
const form = reactive({ name: '', subject: '', body: '', format: 'text' });

const open = (template = null) => {
  editingKey.value = template?.key || null;
  Object.assign(form, {
    name: template?.name || '',
    subject: template?.subject || '',
    body: template?.body || '',
    format: template?.format || 'text',
  });
  lastEditor.value = 'body';
  panelRef.value?.open();
};

// Click a variable to put it where you were typing; drag it to drop it anywhere.
const insertVariable = key =>
  (lastEditor.value === 'subject' ? subjectEditor : bodyEditor).value?.insert(
    key
  );
const onDragStart = (event, key) => {
  event.dataTransfer.setData(bodyEditor.value.dragType, key);
  event.dataTransfer.setData('text/plain', '');
  event.dataTransfer.effectAllowed = 'copyMove';
};

// Switching format keeps the content: paragraphs become <p> and back.
const STARTER_HTML =
  '<div style="font-family: Arial, sans-serif; font-size: 15px; line-height: 1.6; color: #1f2937;">\n  <p>Hi {{ contact.first_name }},</p>\n  <p></p>\n  <p>{{ business.name }}</p>\n</div>';
const formatOptions = computed(() => [
  { id: 'text', icon: 'i-lucide-text', label: t(`${V}.FORMAT_TEXT`) },
  { id: 'html', icon: 'i-lucide-code-xml', label: t(`${V}.FORMAT_HTML`) },
]);
const format = computed({
  get: () => form.format,
  set: value => {
    if (value === form.format) return;
    if (value === 'html') {
      form.body = form.body.trim()
        ? form.body
            .split(/\n{2,}/)
            .map(paragraph => `<p>${paragraph.replace(/\n/g, '<br>')}</p>`)
            .join('\n')
        : STARTER_HTML;
    } else {
      const doc = new DOMParser().parseFromString(
        form.body
          .replace(/<br\s*\/?>/gi, '\n')
          .replace(/<\/(p|div|h[1-6]|li)>/gi, '\n\n'),
        'text/html'
      );
      form.body = doc.body.textContent.replace(/\n{3,}/g, '\n\n').trim();
    }
    form.format = value;
  },
});

const escapeHtml = text =>
  String(text)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
const fill = (text, escape = false) =>
  text.replace(/\{\{\s*([\w.]+)\s*\}\}/g, (match, key) => {
    const value = variables.value.find(item => item.key === key)?.sample ?? '';
    return escape ? escapeHtml(value) : value;
  });
const previewSubject = computed(() => fill(form.subject));
const previewText = computed(() => fill(form.body));
// The iframe has no permissions, so pasted HTML can't run scripts in the app.
const previewHtml = computed(
  () =>
    `<!doctype html><html><body style="margin:0;padding:16px;background:#fff">${fill(form.body, true)}</body></html>`
);
const sampleRecipient = computed(() => {
  const name = variables.value.find(item => item.key === 'contact.name');
  const email = variables.value.find(item => item.key === 'contact.email');
  return `${name.sample} <${email.sample}>`;
});

// The reference scenarios use is made from the name and never shown.
const slugify = name =>
  name
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 36) || 'template';
const newKey = name => {
  const base = slugify(name);
  let key = base;
  let suffix = 2;
  while (templates.value[key]) {
    key = `${base}_${suffix}`;
    suffix += 1;
  }
  return key;
};

const canAdd = computed(() => templateList.value.length < MAX_TEMPLATES);
const isValid = computed(
  () => form.name.trim() && form.subject.trim() && form.body.trim()
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
  const key = editingKey.value || newKey(form.name);
  const next = {
    ...templates.value,
    [key]: {
      name: form.name.trim(),
      subject: form.subject.trim(),
      body: form.body.trim(),
      format: form.format,
    },
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

onMounted(() => {
  if (!(contactAttributes.value || []).length) store.dispatch('attributes/get');
});

defineExpose({ open, canAdd });
</script>

<template>
  <section class="flex flex-col gap-5" data-test="email-templates">
    <p class="max-w-3xl m-0 text-sm text-n-slate-11">
      {{ t('CAPTAIN.AGENT_UX.TOOLS.INTRO.EMAIL_TEMPLATES') }}
    </p>

    <div
      v-if="!templateList.length"
      class="flex flex-col items-center gap-3 px-6 py-10 text-center border border-dashed rounded-xl border-n-strong"
      data-test="email-templates-empty"
    >
      <span class="i-lucide-mail size-6 text-n-slate-10" />
      <p class="m-0 text-sm text-n-slate-11">
        {{ t('CAPTAIN.EMAIL_TEMPLATES.EMPTY') }}
      </p>
      <Button
        sm
        icon="i-lucide-plus"
        :label="t('CAPTAIN.AGENT_UX.TOOLS.NEW_TEMPLATE')"
        data-test="email-template-add"
        @click="open()"
      />
    </div>

    <ul
      v-else
      class="flex flex-col p-0 m-0 list-none border divide-y rounded-xl border-n-weak divide-n-weak"
    >
      <li
        v-for="template in templateList"
        :key="template.key"
        class="flex items-center gap-3 px-4 py-3"
        data-test="email-template-row"
      >
        <span
          class="flex items-center justify-center rounded-lg size-8 shrink-0 bg-n-alpha-2 text-n-slate-11"
        >
          <span
            :class="
              template.format === 'html' ? 'i-lucide-code-xml' : 'i-lucide-mail'
            "
            class="size-4"
          />
        </span>
        <button
          type="button"
          class="flex flex-col flex-1 min-w-0 text-start"
          @click="open(template)"
        >
          <span class="text-sm font-medium truncate text-n-slate-12">
            {{ template.name || template.key }}
          </span>
          <span class="text-sm truncate text-n-slate-11">
            {{ fill(template.subject) }}
          </span>
        </button>
        <span
          class="hidden px-2 py-0.5 text-xs rounded-md sm:inline bg-n-alpha-2 text-n-slate-11"
        >
          {{
            template.format === 'html'
              ? t(`${V}.FORMAT_HTML`)
              : t(`${V}.FORMAT_TEXT`)
          }}
        </span>
        <div class="flex gap-1 shrink-0">
          <Button
            sm
            faded
            slate
            :label="t('CAPTAIN.AGENT_UX.EDIT')"
            @click="open(template)"
          />
          <Button
            sm
            ghost
            ruby
            icon="i-lucide-trash-2"
            :aria-label="t('CAPTAIN.EMAIL_TEMPLATES.DELETE')"
            :disabled="isSaving"
            @click="remove(template.key)"
          />
        </div>
      </li>
    </ul>

    <SidePanel
      ref="panelRef"
      width="5xl"
      :title="
        editingKey
          ? t('CAPTAIN.EMAIL_TEMPLATES.EDIT')
          : t('CAPTAIN.AGENT_UX.TOOLS.NEW_TEMPLATE')
      "
    >
      <div
        class="grid items-start gap-6 xl:grid-cols-[13rem_minmax(0,1fr)_22rem]"
        data-test="email-template-form"
      >
        <aside class="flex flex-col gap-4 xl:sticky xl:top-0">
          <div class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t(`${V}.VARIABLES_TITLE`) }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{ t(`${V}.VARIABLES_HINT`) }}
            </span>
          </div>
          <div
            v-for="group in groupedVariables"
            :key="group.group"
            class="flex flex-col gap-1.5"
          >
            <span
              class="text-xs font-medium tracking-wide uppercase text-n-slate-10"
            >
              {{ t(`${V}.GROUPS.${group.group}`) }}
            </span>
            <div class="flex flex-wrap gap-1.5">
              <span
                v-for="variable in group.items"
                :key="variable.key"
                role="button"
                tabindex="0"
                draggable="true"
                class="px-2 py-1 text-xs font-medium rounded-md select-none cursor-grab active:cursor-grabbing bg-n-blue-3 text-n-blue-11 hover:bg-n-blue-4"
                @click="insertVariable(variable.key)"
                @keydown.enter.prevent="insertVariable(variable.key)"
                @dragstart="onDragStart($event, variable.key)"
              >
                {{ variable.label }}
              </span>
            </div>
          </div>
        </aside>

        <div class="flex flex-col gap-4 min-w-0">
          <Input
            v-model="form.name"
            :label="t('CAPTAIN.EMAIL_TEMPLATES.FIELDS.NAME')"
            :placeholder="t('CAPTAIN.EMAIL_TEMPLATES.FIELDS.NAME_PLACEHOLDER')"
          />
          <div class="flex flex-col gap-1.5">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('CAPTAIN.EMAIL_TEMPLATES.FIELDS.SUBJECT') }}
            </span>
            <VariableEditor
              ref="subjectEditor"
              v-model="form.subject"
              :variables="editorVariables"
              :label="t('CAPTAIN.EMAIL_TEMPLATES.FIELDS.SUBJECT')"
              :placeholder="t(`${V}.SUBJECT_PLACEHOLDER`)"
              @focus="lastEditor = 'subject'"
            />
          </div>
          <div class="flex flex-col gap-1.5">
            <div class="flex items-center justify-between gap-3">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('CAPTAIN.EMAIL_TEMPLATES.FIELDS.BODY') }}
              </span>
              <SegmentedChoice
                v-model="format"
                class="w-64 !flex-nowrap"
                :label="t(`${V}.FORMAT_LABEL`)"
                :options="formatOptions"
              />
            </div>
            <VariableEditor
              :key="form.format"
              ref="bodyEditor"
              v-model="form.body"
              :variables="editorVariables"
              :label="t('CAPTAIN.EMAIL_TEMPLATES.FIELDS.BODY')"
              :placeholder="t(`${V}.BODY_PLACEHOLDER`)"
              :monospace="form.format === 'html'"
              multiline
              @focus="lastEditor = 'body'"
            />
            <span class="text-xs text-n-slate-11">
              {{
                form.format === 'html'
                  ? t(`${V}.HTML_HINT`)
                  : t(`${V}.TEXT_HINT`)
              }}
            </span>
          </div>
        </div>

        <div
          class="flex flex-col overflow-hidden border rounded-xl border-n-weak xl:sticky xl:top-0"
          data-test="email-template-preview"
        >
          <div
            class="flex flex-col gap-1 px-4 py-3 text-xs border-b border-n-weak bg-n-alpha-1 text-n-slate-11"
          >
            <span>
              {{ t(`${V}.FROM`) }}
              <span class="text-n-slate-12">{{ agentName }}</span>
            </span>
            <span>
              {{ t(`${V}.TO`) }}
              <span class="text-n-slate-12">{{ sampleRecipient }}</span>
            </span>
            <span class="pt-1 text-sm font-semibold text-n-slate-12">
              {{ previewSubject || t(`${V}.NO_SUBJECT`) }}
            </span>
          </div>
          <iframe
            v-if="form.format === 'html'"
            :srcdoc="previewHtml"
            sandbox=""
            :title="t(`${V}.PREVIEW_TITLE`)"
            class="w-full bg-white border-0 h-96"
          />
          <p
            v-else
            class="px-4 py-4 m-0 text-sm leading-relaxed whitespace-pre-line bg-n-solid-1 text-n-slate-12 min-h-48"
          >
            {{ previewText || t(`${V}.EMPTY_BODY`) }}
          </p>
          <span
            class="px-4 py-2 text-xs border-t border-n-weak text-n-slate-10"
          >
            {{ t(`${V}.SAMPLE_NOTE`) }}
          </span>
        </div>
      </div>
      <template #footer>
        <div class="flex justify-end gap-2">
          <Button
            type="button"
            faded
            slate
            :label="t('CAPTAIN.AGENT_UX.CANCEL')"
            @click="panelRef?.close()"
          />
          <Button
            type="button"
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

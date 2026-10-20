<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import api from 'dashboard/api/captain/knowledgeSources';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({ assistantId: { type: Number, required: true } });
const emit = defineEmits(['changed']);
const activeSection = defineModel('activeSection', {
  type: String,
  default: null,
});

// Below this, the flat list stays easy to manage.
const MIN_DOCUMENTS = 10;
const FILES_KEY = 'files';
const ACTIONS = ['pause', 'resume', 'retry', 'suggest_faqs', 'delete'];
const { t } = useI18n();
const request = useAbortableRequest();
const sections = ref([]);
const selected = ref(new Set());
const expanded = ref(false);
const running = ref(null);
const deleteDialog = ref(null);

const total = computed(() =>
  sections.value.reduce((sum, section) => sum + section.count, 0)
);
const visible = computed(
  () => sections.value.length > 1 && total.value >= MIN_DOCUMENTS
);
const selectedSections = computed(() =>
  sections.value.filter(section => selected.value.has(section.key))
);
const selectedCount = computed(() =>
  selectedSections.value.reduce((sum, section) => sum + section.count, 0)
);
const sectionLabel = key =>
  key === FILES_KEY ? t('CAPTAIN.DOCUMENT_SECTIONS.FILES') : key;

const load = async () => {
  try {
    const response = await request.run(signal =>
      api.sections(props.assistantId, signal)
    );
    if (!response) return;
    sections.value = response.data.sections;
    const keys = new Set(sections.value.map(section => section.key));
    selected.value = new Set([...selected.value].filter(key => keys.has(key)));
  } catch {
    sections.value = [];
  }
};

const toggle = key => {
  const next = new Set(selected.value);
  next[next.has(key) ? 'delete' : 'add'](key);
  selected.value = next;
};

const run = async action => {
  running.value = action;
  try {
    const { data } = await api.sectionAction(
      props.assistantId,
      [...selected.value],
      action
    );
    useAlert(
      t(`CAPTAIN.DOCUMENT_SECTIONS.DONE.${action.toUpperCase()}`, {
        count: data.count,
      })
    );
    if (action === 'delete') selected.value = new Set();
    emit('changed');
    await load();
  } catch {
    useAlert(t('CAPTAIN.DOCUMENT_SECTIONS.ERROR'));
  } finally {
    running.value = null;
  }
};

const onAction = action => {
  if (action === 'delete') deleteDialog.value.open();
  else run(action);
};

const confirmDelete = async () => {
  await run('delete');
  deleteDialog.value.close();
};

const show = key => {
  activeSection.value = activeSection.value === key ? null : key;
};

watch(() => props.assistantId, load, { immediate: true });
defineExpose({ load });
</script>

<template>
  <section v-if="visible" class="mb-4 rounded-xl border border-n-weak p-4">
    <button
      type="button"
      class="flex w-full items-center justify-between gap-3 border-0 bg-transparent p-0 text-start"
      :aria-expanded="expanded"
      @click="expanded = !expanded"
    >
      <span class="flex flex-col">
        <span class="text-sm font-medium text-n-slate-12">
          {{
            $t('CAPTAIN.DOCUMENT_SECTIONS.TITLE', { count: sections.length })
          }}
        </span>
        <span class="text-xs text-n-slate-11">
          {{ $t('CAPTAIN.DOCUMENT_SECTIONS.DESCRIPTION') }}
        </span>
      </span>
      <span
        class="size-4 shrink-0 text-n-slate-11"
        :class="expanded ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'"
      />
    </button>
    <template v-if="expanded">
      <div
        v-if="selected.size"
        class="mt-3 flex flex-wrap items-center gap-2 rounded-lg bg-n-alpha-1 p-2"
      >
        <span class="me-1 text-xs text-n-slate-12">
          {{
            $t('CAPTAIN.DOCUMENT_SECTIONS.SELECTED', {
              sections: selected.size,
              count: selectedCount,
            })
          }}
        </span>
        <Button
          v-for="action in ACTIONS"
          :key="action"
          xs
          :variant="action === 'delete' ? 'ghost' : 'faded'"
          :color="action === 'delete' ? 'ruby' : 'slate'"
          :label="
            $t(`CAPTAIN.DOCUMENT_SECTIONS.ACTIONS.${action.toUpperCase()}`)
          "
          :is-loading="running === action"
          :disabled="Boolean(running)"
          @click="onAction(action)"
        />
      </div>
      <ul class="m-0 mt-3 flex max-h-72 flex-col gap-1 overflow-auto p-0">
        <li
          v-for="section in sections"
          :key="section.key"
          class="flex list-none items-center gap-3 rounded-lg px-2 py-1.5 hover:bg-n-alpha-1"
          :class="{ 'bg-n-alpha-1': activeSection === section.key }"
        >
          <Checkbox
            :model-value="selected.has(section.key)"
            @update:model-value="toggle(section.key)"
          />
          <span class="min-w-0 flex-1 truncate text-sm text-n-slate-12">
            {{ sectionLabel(section.key) }}
          </span>
          <span class="shrink-0 text-xs tabular-nums text-n-slate-11">
            {{
              $t('CAPTAIN.DOCUMENT_SECTIONS.COUNTS', {
                count: section.count,
                ready: section.ready,
              })
            }}
          </span>
          <span
            v-if="section.failed"
            class="shrink-0 text-xs tabular-nums text-n-ruby-11"
          >
            {{
              $t('CAPTAIN.DOCUMENT_SECTIONS.FAILED', { count: section.failed })
            }}
          </span>
          <span
            v-if="section.paused"
            class="shrink-0 text-xs tabular-nums text-n-slate-11"
          >
            {{
              $t('CAPTAIN.DOCUMENT_SECTIONS.PAUSED', { count: section.paused })
            }}
          </span>
          <Button
            xs
            link
            :label="
              activeSection === section.key
                ? $t('CAPTAIN.DOCUMENT_SECTIONS.SHOW_ALL')
                : $t('CAPTAIN.DOCUMENT_SECTIONS.SHOW')
            "
            @click="show(section.key)"
          />
        </li>
      </ul>
    </template>
    <Dialog
      ref="deleteDialog"
      type="alert"
      :title="$t('CAPTAIN.DOCUMENT_SECTIONS.DELETE_TITLE')"
      :description="
        $t('CAPTAIN.DOCUMENT_SECTIONS.DELETE_DESCRIPTION', {
          count: selectedCount,
        })
      "
      :confirm-button-label="$t('CAPTAIN.DOCUMENT_SECTIONS.ACTIONS.DELETE')"
      :is-loading="running === 'delete'"
      @confirm="confirmDelete"
    />
  </section>
</template>

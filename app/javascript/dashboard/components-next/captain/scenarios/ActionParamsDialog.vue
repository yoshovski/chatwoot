<script setup>
import { ref, reactive, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  ROUND_ROBIN,
  FOLLOW_UP_DELAYS,
  actionChipTitle,
  buildToolReference,
  formatDelay,
} from './builtInActions';

// The fixed-parameter step of a built-in action: which attribute, team, agent, template or delay.
const emit = defineEmits(['insert', 'newTemplate']);

const { t } = useI18n();
const store = useStore();
const route = useRoute();

const ATTRIBUTE_MODELS = {
  update_contact_attribute: 'contact_attribute',
  update_conversation_attribute: 'conversation_attribute',
};
const DEFAULTS = {
  assign_agent: { agent_id: ROUND_ROBIN },
  email_team: { recipient: 'assignee' },
  schedule_follow_up: { after: '60', kind: 'message' },
};
const INSTRUCTIONS_LIMIT = 500;

const dialogRef = ref(null);
const tool = ref(null);
const params = reactive({});
const newAttribute = reactive({
  open: false,
  name: '',
  key: '',
  type: 'text',
  saving: false,
});

const toolId = computed(() => tool.value?.id);
const attributeModel = computed(() => ATTRIBUTE_MODELS[toolId.value]);
const attributes = computed(() =>
  attributeModel.value
    ? store.getters['attributes/getAttributesByModel'](attributeModel.value)
    : []
);
const teams = computed(() => store.getters['teams/getTeams'] || []);
const agents = computed(() => store.getters['agents/getAgents'] || []);
const templates = computed(
  () =>
    store.getters['captainAssistants/getRecord'](
      Number(route.params.assistantId)
    )?.config?.email_templates || {}
);

const shows = field =>
  ({
    attribute: ['update_contact_attribute', 'update_conversation_attribute'],
    team: ['assign_team'],
    agent: ['assign_agent'],
    recipient: ['email_team'],
    template: ['email_visitor', 'email_team'],
    followUp: ['schedule_follow_up'],
  })[field].includes(toolId.value);

const attributeOptions = computed(() =>
  attributes.value.map(attribute => ({
    value: attribute.attribute_key,
    label: attribute.attribute_display_name,
  }))
);
const teamOptions = computed(() =>
  teams.value.map(team => ({ value: String(team.id), label: team.name }))
);
const agentOptions = computed(() => [
  {
    value: ROUND_ROBIN,
    label: t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.FIELDS.NEXT_AVAILABLE'),
  },
  ...agents.value.map(agent => ({
    value: String(agent.id),
    label: agent.name,
  })),
]);
const recipientOptions = computed(() => [
  {
    value: 'assignee',
    label: t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.FIELDS.ASSIGNEE'),
  },
  ...teams.value.map(team => ({ value: `team:${team.id}`, label: team.name })),
]);
const templateOptions = computed(() =>
  Object.entries(templates.value).map(([key, template]) => ({
    value: key,
    label: template.name || key,
  }))
);
const delayOptions = computed(() =>
  FOLLOW_UP_DELAYS.map(minutes => ({
    value: String(minutes),
    label: formatDelay(minutes, t),
  }))
);
const kindOptions = computed(() => [
  {
    value: 'message',
    label: t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.FIELDS.KIND_MESSAGE'),
  },
  {
    value: 'email',
    label: t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.FIELDS.KIND_EMAIL'),
  },
]);
const typeOptions = computed(() => [
  { value: 'text', label: t('ATTRIBUTES_MGMT.ATTRIBUTE_TYPES.TEXT') },
  { value: 'number', label: t('ATTRIBUTES_MGMT.ATTRIBUTE_TYPES.NUMBER') },
  { value: 'link', label: t('ATTRIBUTES_MGMT.ATTRIBUTE_TYPES.LINK') },
  { value: 'date', label: t('ATTRIBUTES_MGMT.ATTRIBUTE_TYPES.DATE') },
  { value: 'list', label: t('ATTRIBUTES_MGMT.ATTRIBUTE_TYPES.LIST') },
  { value: 'checkbox', label: t('ATTRIBUTES_MGMT.ATTRIBUTE_TYPES.CHECKBOX') },
]);

const isValid = computed(() => {
  switch (toolId.value) {
    case 'update_contact_attribute':
    case 'update_conversation_attribute':
      return Boolean(params.key);
    case 'assign_team':
      return Boolean(params.team_id);
    case 'assign_agent':
      return Boolean(params.agent_id);
    case 'email_visitor':
      return Boolean(params.template);
    case 'email_team':
      return Boolean(params.recipient && params.template);
    case 'schedule_follow_up':
      if (params.kind === 'email') return Boolean(params.template);
      return Boolean(params.template || params.instructions?.trim());
    default:
      return false;
  }
});

const loadLookups = () => {
  if (attributeModel.value && !attributes.value.length) {
    store.dispatch('attributes/get');
  }
  if (!teams.value.length) store.dispatch('teams/get');
  if (toolId.value === 'assign_agent' && !agents.value.length) {
    store.dispatch('agents/get');
  }
};

const open = (selectedTool, preset = {}) => {
  tool.value = selectedTool;
  Object.keys(params).forEach(key => delete params[key]);
  Object.assign(params, DEFAULTS[selectedTool.id] || {}, preset);
  newAttribute.open = false;
  loadLookups();
  // Templates may have been added in another tab since the agent was loaded.
  if (
    route.params.assistantId &&
    ['email_visitor', 'email_team', 'schedule_follow_up'].includes(
      selectedTool.id
    )
  ) {
    store.dispatch('captainAssistants/show', Number(route.params.assistantId));
  }
  dialogRef.value?.open();
};

const slugify = name =>
  name
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');

const onNewAttributeName = value => {
  newAttribute.name = value;
  newAttribute.key = slugify(value);
};

const createAttribute = async () => {
  newAttribute.saving = true;
  try {
    await store.dispatch('attributes/create', {
      attribute_display_name: newAttribute.name.trim(),
      attribute_key: newAttribute.key,
      attribute_display_type: newAttribute.type,
      attribute_model: attributeModel.value,
    });
    params.key = newAttribute.key;
    newAttribute.open = false;
  } catch (error) {
    useAlert(
      error?.message ||
        t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.CREATE_ATTRIBUTE.ERROR')
    );
  } finally {
    newAttribute.saving = false;
  }
};

const insert = () => {
  if (!isValid.value) return;
  const fixed = { ...params };
  if (fixed.agent_id !== ROUND_ROBIN) delete fixed.team_id;
  if (fixed.template) delete fixed.instructions;
  const lookups = {
    attributes: attributes.value,
    teams: teams.value,
    agents: agents.value,
    templates: templates.value,
  };
  emit('insert', {
    id: buildToolReference(toolId.value, fixed),
    title: actionChipTitle(toolId.value, fixed, lookups, t),
    emoji: tool.value.emoji,
  });
  dialogRef.value?.close();
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="tool?.title"
    :description="tool?.description"
    :confirm-button-label="t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.INSERT')"
    :disable-confirm-button="!isValid"
    overflow-y-auto
    @confirm="insert"
  >
    <div class="flex flex-col gap-4" data-test="action-params">
      <template v-if="shows('attribute')">
        <label class="flex flex-col gap-1 text-sm text-n-slate-12">
          {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.FIELDS.ATTRIBUTE') }}
          <Select
            v-model="params.key"
            :options="attributeOptions"
            :placeholder="
              t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.FIELDS.PICK_ATTRIBUTE')
            "
            data-test="attribute-select"
          />
        </label>
        <Button
          v-if="!newAttribute.open"
          type="button"
          xs
          link
          icon="i-lucide-plus"
          :label="
            t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.CREATE_ATTRIBUTE.OPEN')
          "
          class="self-start"
          data-test="create-attribute"
          @click="newAttribute.open = true"
        />
        <div
          v-else
          class="flex flex-col gap-3 p-3 border rounded-lg border-n-weak"
          data-test="create-attribute-form"
        >
          <Input
            :model-value="newAttribute.name"
            :label="
              t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.CREATE_ATTRIBUTE.NAME')
            "
            @update:model-value="onNewAttributeName"
          />
          <Input
            v-model="newAttribute.key"
            :label="
              t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.CREATE_ATTRIBUTE.KEY')
            "
          />
          <label class="flex flex-col gap-1 text-sm text-n-slate-12">
            {{
              t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.CREATE_ATTRIBUTE.TYPE')
            }}
            <Select v-model="newAttribute.type" :options="typeOptions" />
          </label>
          <div class="flex gap-2">
            <Button
              type="button"
              sm
              :label="
                t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.CREATE_ATTRIBUTE.SAVE')
              "
              :is-loading="newAttribute.saving"
              :disabled="!newAttribute.name.trim() || !newAttribute.key"
              data-test="save-attribute"
              @click="createAttribute"
            />
            <Button
              type="button"
              sm
              faded
              slate
              :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.CANCEL')"
              @click="newAttribute.open = false"
            />
          </div>
        </div>
      </template>

      <label
        v-if="shows('team')"
        class="flex flex-col gap-1 text-sm text-n-slate-12"
      >
        {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.FIELDS.TEAM') }}
        <Select
          v-model="params.team_id"
          :options="teamOptions"
          :placeholder="t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.FIELDS.PICK')"
        />
      </label>

      <template v-if="shows('agent')">
        <label class="flex flex-col gap-1 text-sm text-n-slate-12">
          {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.FIELDS.AGENT') }}
          <Select v-model="params.agent_id" :options="agentOptions" />
        </label>
        <label
          v-if="params.agent_id === ROUND_ROBIN"
          class="flex flex-col gap-1 text-sm text-n-slate-12"
        >
          {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.FIELDS.FROM_TEAM') }}
          <Select
            v-model="params.team_id"
            :options="teamOptions"
            :placeholder="
              t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.FIELDS.ANY_TEAM')
            "
          />
        </label>
      </template>

      <label
        v-if="shows('recipient')"
        class="flex flex-col gap-1 text-sm text-n-slate-12"
      >
        {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.FIELDS.RECIPIENT') }}
        <Select v-model="params.recipient" :options="recipientOptions" />
      </label>

      <template v-if="shows('followUp')">
        <label class="flex flex-col gap-1 text-sm text-n-slate-12">
          {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.FIELDS.AFTER') }}
          <Select v-model="params.after" :options="delayOptions" />
        </label>
        <label class="flex flex-col gap-1 text-sm text-n-slate-12">
          {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.FIELDS.KIND') }}
          <Select v-model="params.kind" :options="kindOptions" />
        </label>
      </template>

      <label
        v-if="shows('template') || shows('followUp')"
        class="flex flex-col gap-1 text-sm text-n-slate-12"
      >
        {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.FIELDS.TEMPLATE') }}
        <Select
          v-model="params.template"
          :options="templateOptions"
          :placeholder="
            shows('followUp') && params.kind !== 'email'
              ? t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.FIELDS.AI_WRITES')
              : t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.FIELDS.PICK')
          "
          data-test="template-select"
        />
        <Button
          type="button"
          xs
          link
          icon="i-lucide-plus"
          :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.NEW_TEMPLATE')"
          class="self-start"
          @click="emit('newTemplate')"
        />
      </label>

      <TextArea
        v-if="shows('followUp') && params.kind !== 'email' && !params.template"
        v-model="params.instructions"
        :max-length="INSTRUCTIONS_LIMIT"
        :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.FIELDS.INSTRUCTIONS')"
        :placeholder="
          t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.FIELDS.INSTRUCTIONS_HINT')
        "
        show-character-count
        auto-height
      />
    </div>
  </Dialog>
</template>

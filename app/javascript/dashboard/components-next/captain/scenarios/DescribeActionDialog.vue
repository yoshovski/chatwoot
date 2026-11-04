<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import CaptainScenariosAPI from 'dashboard/api/captain/scenarios';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ToolChip from './ToolChip.vue';
import { actionChipTitle, buildToolReference } from './builtInActions';

// "Describe an action": a sentence in, a suggested action out. Nothing is inserted or created until the user confirms.
const emit = defineEmits(['insert']);

const { t } = useI18n();
const store = useStore();
const route = useRoute();

const ATTRIBUTE_MODELS = {
  update_contact_attribute: 'contact_attribute',
  update_conversation_attribute: 'conversation_attribute',
};
const DESCRIPTION_LIMIT = 500;

const dialogRef = ref(null);
const description = ref('');
const suggestion = ref(null);
const noMatch = ref(false);
const isLoading = ref(false);
const isCreating = ref(false);

const tools = computed(() => store.getters['captainTools/getRecords'] || []);
const missingAttribute = computed(() => suggestion.value?.missing?.attribute);
const suggestedTool = computed(() =>
  tools.value.find(tool => tool.id === suggestion.value?.tool_id)
);

const chipTitle = computed(() => {
  if (!suggestion.value) return '';
  const { tool_id: toolId, params } = suggestion.value;
  if (!Object.keys(params).length) return suggestedTool.value?.title || toolId;
  const lookups = {
    attributes: [
      ...store.getters['attributes/getAttributes'],
      ...(missingAttribute.value
        ? [
            {
              attribute_key: missingAttribute.value.key,
              attribute_display_name: missingAttribute.value.label,
            },
          ]
        : []),
    ],
    teams: store.getters['teams/getTeams'] || [],
    agents: store.getters['agents/getAgents'] || [],
    templates:
      store.getters['captainAssistants/getRecord'](
        Number(route.params.assistantId)
      )?.config?.email_templates || {},
  };
  return actionChipTitle(toolId, params, lookups, t);
});

const open = () => {
  description.value = '';
  suggestion.value = null;
  noMatch.value = false;
  dialogRef.value?.open();
};

const suggest = async () => {
  isLoading.value = true;
  noMatch.value = false;
  try {
    const { data } = await CaptainScenariosAPI.suggestAction({
      assistantId: route.params.assistantId,
      description: description.value.trim(),
    });
    suggestion.value = data.suggestion;
    noMatch.value = !data.suggestion;
  } catch {
    useAlert(t('CAPTAIN.ASSISTANTS.SCENARIOS.DESCRIBE.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const insert = () => {
  const { tool_id: toolId, params } = suggestion.value;
  emit('insert', {
    id: buildToolReference(toolId, params),
    title: chipTitle.value,
    emoji: suggestedTool.value?.emoji,
  });
  dialogRef.value?.close();
};

// The missing attribute is created only now, after the user said yes.
const createAndInsert = async () => {
  isCreating.value = true;
  try {
    await store.dispatch('attributes/create', {
      attribute_display_name: missingAttribute.value.label,
      attribute_key: missingAttribute.value.key,
      attribute_display_type: missingAttribute.value.type,
      attribute_model: ATTRIBUTE_MODELS[suggestion.value.tool_id],
    });
    insert();
  } catch (error) {
    useAlert(
      error?.message ||
        t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.CREATE_ATTRIBUTE.ERROR')
    );
  } finally {
    isCreating.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('CAPTAIN.ASSISTANTS.SCENARIOS.DESCRIBE.TITLE')"
    :description="t('CAPTAIN.ASSISTANTS.SCENARIOS.DESCRIBE.DESCRIPTION')"
    :show-confirm-button="false"
    overflow-y-auto
  >
    <div class="flex flex-col gap-4" data-test="describe-action">
      <TextArea
        v-model="description"
        :max-length="DESCRIPTION_LIMIT"
        :placeholder="t('CAPTAIN.ASSISTANTS.SCENARIOS.DESCRIBE.PLACEHOLDER')"
        auto-height
      />
      <Button
        type="button"
        sm
        class="self-start"
        :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.DESCRIBE.SUGGEST')"
        :is-loading="isLoading"
        :disabled="description.trim().length < 3"
        data-test="describe-suggest"
        @click="suggest"
      />

      <p v-if="noMatch" class="mb-0 text-sm text-n-slate-11">
        {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.DESCRIBE.NO_MATCH') }}
      </p>

      <div v-if="suggestion" class="flex flex-col gap-3">
        <div class="flex items-center gap-2 text-sm text-n-slate-12">
          {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.DESCRIBE.PREVIEW') }}
          <ToolChip
            :tool-id="suggestion.tool_id"
            :label="chipTitle"
            data-test="describe-chip"
          />
        </div>
        <template v-if="missingAttribute">
          <p class="mb-0 text-sm text-n-slate-12" data-test="describe-missing">
            {{
              t('CAPTAIN.ASSISTANTS.SCENARIOS.DESCRIBE.CREATE_ATTRIBUTE', {
                key: missingAttribute.key,
                type: missingAttribute.type,
              })
            }}
          </p>
          <div class="flex gap-2">
            <Button
              type="button"
              sm
              :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.DESCRIBE.CREATE')"
              :is-loading="isCreating"
              data-test="describe-create"
              @click="createAndInsert"
            />
            <Button
              type="button"
              sm
              faded
              slate
              :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.CANCEL')"
              @click="suggestion = null"
            />
          </div>
        </template>
        <Button
          v-else
          type="button"
          sm
          class="self-start"
          :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.ACTIONS.INSERT')"
          data-test="describe-insert"
          @click="insert"
        />
      </div>
    </div>
  </Dialog>
</template>

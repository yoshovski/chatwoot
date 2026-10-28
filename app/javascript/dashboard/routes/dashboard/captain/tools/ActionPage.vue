<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { onBeforeRouteLeave, useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import CustomToolsAPI from 'dashboard/api/captain/customTools';

import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Accordion from 'dashboard/components-next/Accordion/Accordion.vue';
import ParamRow from 'dashboard/components-next/captain/pageComponents/customTool/ParamRow.vue';
import AuthConfig from 'dashboard/components-next/captain/pageComponents/customTool/AuthConfig.vue';
import StepRow from 'dashboard/components-next/captain/pageComponents/customTool/action/StepRow.vue';
import StepPanel from 'dashboard/components-next/captain/pageComponents/customTool/action/StepPanel.vue';
import VariablePicker from 'dashboard/components-next/captain/pageComponents/customTool/action/VariablePicker.vue';
import {
  canAddStep,
  fromTool,
  moveStep,
  newStep,
  removeStep,
  toPayload,
  variablesBefore,
} from 'dashboard/components-next/captain/pageComponents/customTool/action/actionForm';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();

const toolId = computed(() =>
  route.params.toolId ? Number(route.params.toolId) : null
);
const form = reactive(fromTool());
const isLoading = ref(!!toolId.value);
const isSaving = ref(false);
const savedSnapshot = ref('');
const serverErrors = ref({});
const titleError = ref('');
const openStepIndex = ref(null);
const testResult = ref(null);
const showMessages = ref(false);
const modeTouched = ref(!!toolId.value);

// Copy names the AI agent this action belongs to, e.g. "Visible to Store Bot".
const agentName = computed(
  () =>
    store.getters['captainAssistants/getRecord'](
      Number(route.params.assistantId)
    )?.name || t('CAPTAIN.CUSTOM_TOOLS.ACTION.AGENT_FALLBACK')
);

const backUrl = computed(() => ({
  name: 'captain_tools_index',
  params: {
    accountId: route.params.accountId,
    assistantId: route.params.assistantId,
  },
}));
const snapshot = () => JSON.stringify(toPayload(form));
const isDirty = computed(() => snapshot() !== savedSnapshot.value);

const authTypeOptions = computed(() => [
  { value: 'none', label: t('CAPTAIN.CUSTOM_TOOLS.FORM.AUTH_TYPES.NONE') },
  { value: 'bearer', label: t('CAPTAIN.CUSTOM_TOOLS.FORM.AUTH_TYPES.BEARER') },
  { value: 'basic', label: t('CAPTAIN.CUSTOM_TOOLS.FORM.AUTH_TYPES.BASIC') },
  {
    value: 'api_key',
    label: t('CAPTAIN.CUSTOM_TOOLS.FORM.AUTH_TYPES.API_KEY'),
  },
]);

const allOutputs = computed(() => ({
  inputs: form.param_schema.filter(param => param.name).map(p => p.name),
  outputs: form.outputs.map(output => `outputs.${output.key}`),
  contact: variablesBefore(form, 0).contact,
}));
const stepResult = step =>
  testResult.value?.steps?.find(entry => entry.key === step.key) || null;
const stepHasErrors = step =>
  !!serverErrors.value[`steps.${step.key}`] ||
  form.outputs.some(
    output =>
      output.step === step.key && serverErrors.value[`outputs.${output.key}`]
  );
const generalErrors = computed(() =>
  ['steps', 'outputs', 'messages', 'param_schema', 'endpoint_url'].flatMap(
    key => serverErrors.value[key] || []
  )
);

// New actions ask for confirmation once a step changes data, until the admin picks a mode.
watch(
  () => form.steps.map(step => step.method).join(),
  () => {
    if (modeTouched.value) return;
    const readOnly = form.steps.every(
      step => step.type !== 'request' || step.method === 'GET'
    );
    form.execution_mode = readOnly ? 'background' : 'confirm';
  }
);

const selectMode = mode => {
  modeTouched.value = true;
  form.execution_mode = mode;
};

const addParam = () =>
  form.param_schema.push({
    name: '',
    type: 'string',
    description: '',
    required: false,
    test_value: '',
  });

const addStep = type => {
  form.steps.push(newStep(type, form.steps));
  openStepIndex.value = form.steps.length - 1;
};
const move = offset => {
  form.steps = moveStep(form.steps, openStepIndex.value, offset);
  openStepIndex.value += offset;
};
const deleteStep = () => {
  Object.assign(
    form,
    removeStep(form.steps, form.outputs, openStepIndex.value)
  );
};
const openOutputStep = output => {
  openStepIndex.value = form.steps.findIndex(step => step.key === output.step);
};

const appendMessage = (key, text) => {
  form.messages[key] = `${form.messages[key] || ''}${text}`;
};

const confirmPreview = computed(
  () =>
    form.messages.confirm_prompt ||
    t('CAPTAIN.CUSTOM_TOOLS.ACTION.MODE.DEFAULT_PROMPT', {
      // Same as the backend default: "Cancel order" reads "cancel order", acronyms stay.
      title:
        form.title.replace(/^[A-Z](?![A-Z])/, letter => letter.toLowerCase()) ||
        t('CAPTAIN.CUSTOM_TOOLS.ACTION.MODE.THIS_ACTION'),
    })
);

const save = async () => {
  titleError.value = form.title.trim()
    ? ''
    : t('CAPTAIN.CUSTOM_TOOLS.FORM.TITLE.ERROR');
  if (titleError.value) return;

  isSaving.value = true;
  serverErrors.value = {};
  try {
    const payload = toPayload(form);
    if (toolId.value) {
      await CustomToolsAPI.update(toolId.value, payload);
    } else {
      await CustomToolsAPI.create(payload);
    }
    savedSnapshot.value = snapshot();
    useAlert(
      t(
        toolId.value
          ? 'CAPTAIN.CUSTOM_TOOLS.EDIT.SUCCESS_MESSAGE'
          : 'CAPTAIN.CUSTOM_TOOLS.CREATE.SUCCESS_MESSAGE'
      )
    );
    router.push(backUrl.value);
  } catch (error) {
    serverErrors.value = error.response?.data?.errors || {};
    useAlert(
      error.response?.data?.message ||
        error.response?.data?.error ||
        t('CAPTAIN.CUSTOM_TOOLS.EDIT.ERROR_MESSAGE')
    );
  } finally {
    isSaving.value = false;
  }
};

onBeforeRouteLeave(() => {
  if (!isDirty.value) return true;
  // eslint-disable-next-line no-alert
  return window.confirm(t('CAPTAIN.CUSTOM_TOOLS.ACTION.LEAVE'));
});

onMounted(async () => {
  if (toolId.value) {
    try {
      const { data } = await CustomToolsAPI.show(toolId.value);
      Object.assign(form, fromTool(data));
    } catch {
      useAlert(t('CAPTAIN.CUSTOM_TOOLS.ACTION.LOAD_ERROR'));
    }
  } else {
    form.steps.push(newStep('request', form.steps));
  }
  savedSnapshot.value = toolId.value ? snapshot() : '';
  isLoading.value = false;
});
</script>

<template>
  <PageLayout
    :header-title="
      toolId
        ? t('CAPTAIN.CUSTOM_TOOLS.ACTION.EDIT_TITLE')
        : t('CAPTAIN.CUSTOM_TOOLS.ACTION.NEW_TITLE')
    "
    :back-url="backUrl"
    :show-pagination-footer="false"
    :show-know-more="false"
    :is-fetching="isLoading"
    container-class="max-w-3xl"
  >
    <template #headerActions>
      <Button
        :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.SAVE')"
        size="sm"
        :is-loading="isSaving"
        :disabled="isSaving || isLoading"
        @click="save"
      />
    </template>

    <template #body>
      <form class="flex flex-col gap-10 pb-16" @submit.prevent="save">
        <section class="flex flex-col gap-4">
          <Input
            v-model="form.title"
            :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.NAME.LABEL')"
            :placeholder="t('CAPTAIN.CUSTOM_TOOLS.ACTION.NAME.PLACEHOLDER')"
            :message="titleError"
            :message-type="titleError ? 'error' : 'info'"
          />
          <TextArea
            v-model="form.description"
            :label="
              t('CAPTAIN.CUSTOM_TOOLS.ACTION.WHEN.LABEL', { agent: agentName })
            "
            :placeholder="t('CAPTAIN.CUSTOM_TOOLS.ACTION.WHEN.PLACEHOLDER')"
            :rows="2"
            auto-height
          />
        </section>

        <section class="flex flex-col gap-3">
          <div class="flex items-center justify-between gap-2">
            <h2 class="mb-0 text-sm font-medium text-n-slate-12">
              {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.TITLE') }}
            </h2>
            <div class="flex gap-1">
              <Button
                type="button"
                size="xs"
                variant="ghost"
                color="slate"
                icon="i-lucide-plus"
                :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.ADD_REQUEST')"
                :disabled="!canAddStep('request', form.steps)"
                @click="addStep('request')"
              />
              <Button
                type="button"
                size="xs"
                variant="ghost"
                color="slate"
                icon="i-lucide-plus"
                :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.ADD_VERIFY')"
                :disabled="!canAddStep('verify', form.steps)"
                @click="addStep('verify')"
              />
            </div>
          </div>
          <ul
            class="flex flex-col p-1 mb-0 rounded-xl outline outline-1 outline-n-weak"
          >
            <StepRow
              v-for="(step, index) in form.steps"
              :key="step.key"
              :step="step"
              :index="index"
              :result="stepResult(step)"
              :has-errors="stepHasErrors(step)"
              @open="openStepIndex = index"
            />
          </ul>
          <ul
            v-if="generalErrors.length"
            class="mb-0 text-sm list-none text-n-ruby-11"
          >
            <li v-for="error in generalErrors" :key="error">{{ error }}</li>
          </ul>
        </section>

        <section class="flex flex-col gap-3">
          <div class="flex items-center justify-between gap-2">
            <h2 class="mb-0 text-sm font-medium text-n-slate-12">
              {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.INPUTS.TITLE') }}
            </h2>
            <Button
              type="button"
              size="xs"
              variant="ghost"
              color="slate"
              icon="i-lucide-plus"
              :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.INPUTS.ADD')"
              @click="addParam"
            />
          </div>
          <ul
            v-if="form.param_schema.length"
            class="flex flex-col gap-3 mb-0 md:gap-2"
          >
            <ParamRow
              v-for="(param, index) in form.param_schema"
              :key="index"
              v-model:name="param.name"
              v-model:type="param.type"
              v-model:description="param.description"
              v-model:required="param.required"
              @remove="form.param_schema.splice(index, 1)"
            />
          </ul>
          <p v-else class="mb-0 text-sm text-n-slate-10">
            {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.INPUTS.EMPTY') }}
          </p>
        </section>

        <section class="flex flex-col gap-3">
          <h2 class="mb-0 text-sm font-medium text-n-slate-12">
            {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.OUTPUTS.SUMMARY_TITLE') }}
          </h2>
          <div v-if="form.outputs.length" class="flex flex-wrap gap-2">
            <button
              v-for="output in form.outputs"
              :key="`${output.step}.${output.key}`"
              type="button"
              class="flex items-center gap-1.5 px-2.5 py-1 font-mono text-xs rounded-lg outline outline-1 hover:bg-n-alpha-1"
              :class="
                serverErrors[`outputs.${output.key}`]
                  ? 'outline-n-ruby-8 text-n-ruby-11'
                  : 'outline-n-weak text-n-slate-12'
              "
              :title="
                output.available_to_ai
                  ? t('CAPTAIN.CUSTOM_TOOLS.ACTION.OUTPUTS.AI_VISIBLE', {
                      agent: agentName,
                    })
                  : t('CAPTAIN.CUSTOM_TOOLS.ACTION.OUTPUTS.AI_HIDDEN', {
                      agent: agentName,
                    })
              "
              data-test="output-chip"
              @click="openOutputStep(output)"
            >
              <span
                class="size-3.5"
                :class="
                  output.available_to_ai
                    ? 'i-lucide-sparkles text-n-blue-11'
                    : 'i-lucide-eye-off text-n-slate-10'
                "
              />
              {{ output.key }}
            </button>
          </div>
          <p v-else class="mb-0 text-sm text-n-slate-10">
            {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.OUTPUTS.SUMMARY_EMPTY') }}
          </p>
        </section>

        <section class="flex flex-col gap-3">
          <h2 class="mb-0 text-sm font-medium text-n-slate-12">
            {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.MODE.TITLE') }}
          </h2>
          <div
            class="grid grid-cols-2 p-1 rounded-lg bg-n-alpha-1 sm:self-start"
            role="radiogroup"
          >
            <button
              v-for="mode in ['background', 'confirm']"
              :key="mode"
              type="button"
              role="radio"
              :aria-checked="form.execution_mode === mode"
              class="px-3 py-1.5 text-sm rounded-md transition-colors"
              :class="
                form.execution_mode === mode
                  ? 'bg-n-solid-3 text-n-slate-12 shadow-sm'
                  : 'text-n-slate-11 hover:text-n-slate-12'
              "
              @click="selectMode(mode)"
            >
              {{ t(`CAPTAIN.CUSTOM_TOOLS.ACTION.MODE.${mode.toUpperCase()}`) }}
            </button>
          </div>
          <p class="mb-0 text-sm text-n-slate-11">
            {{
              t(
                `CAPTAIN.CUSTOM_TOOLS.ACTION.MODE.${form.execution_mode.toUpperCase()}_HELP`,
                { agent: agentName }
              )
            }}
          </p>
          <template v-if="form.execution_mode === 'confirm'">
            <div class="flex flex-col gap-2 p-4 rounded-xl bg-n-alpha-1">
              <p
                class="self-start px-3 py-2 mb-0 text-sm rounded-xl bg-n-solid-3 text-n-slate-12"
              >
                {{ confirmPreview }}
              </p>
              <div class="flex gap-2">
                <span
                  class="px-3 py-1 text-sm rounded-lg bg-n-solid-3 text-n-blue-11"
                >
                  {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.MODE.CONFIRM_BUTTON') }}
                </span>
                <span
                  class="px-3 py-1 text-sm rounded-lg bg-n-solid-3 text-n-slate-11"
                >
                  {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.MODE.CANCEL_BUTTON') }}
                </span>
              </div>
            </div>
            <Button
              v-if="!showMessages"
              type="button"
              size="xs"
              variant="link"
              color="blue"
              class="self-start"
              :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.MODE.CUSTOMIZE')"
              @click="showMessages = true"
            />
            <template v-else>
              <div
                v-for="key in ['confirm_prompt', 'success', 'failure']"
                :key="key"
                class="flex items-end gap-2"
              >
                <Input
                  v-model="form.messages[key]"
                  :label="
                    t(`CAPTAIN.CUSTOM_TOOLS.ACTION.MODE.${key.toUpperCase()}`)
                  "
                  :placeholder="
                    t(
                      `CAPTAIN.CUSTOM_TOOLS.ACTION.MODE.${key.toUpperCase()}_PLACEHOLDER`
                    )
                  "
                  class="flex-1 min-w-0"
                />
                <VariablePicker
                  :variables="allOutputs"
                  @insert="text => appendMessage(key, text)"
                />
              </div>
            </template>
            <p class="mb-0 text-xs text-n-slate-10">
              {{
                t('CAPTAIN.CUSTOM_TOOLS.ACTION.MODE.CHANNEL_NOTE', {
                  agent: agentName,
                })
              }}
            </p>
          </template>
        </section>

        <Accordion :title="t('CAPTAIN.CUSTOM_TOOLS.ACTION.ADVANCED')">
          <div class="flex flex-col gap-6">
            <div class="flex flex-col gap-2">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.CONNECTION.TITLE') }}
              </span>
              <ComboBox
                v-model="form.auth_type"
                :options="authTypeOptions"
                class="[&>div>button]:bg-n-alpha-black2"
              />
              <AuthConfig
                v-model:auth-config="form.auth_config"
                :auth-type="form.auth_type"
                :configured="form.auth_configured"
              />
            </div>
            <TextArea
              v-model="form.response_template"
              :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.OUTPUTS.TEMPLATE')"
              :placeholder="
                t('CAPTAIN.CUSTOM_TOOLS.ACTION.OUTPUTS.TEMPLATE_PLACEHOLDER')
              "
              :rows="2"
              class="[&_textarea]:font-mono"
            />
          </div>
        </Accordion>
      </form>

      <StepPanel
        v-if="openStepIndex !== null"
        v-model:form="form"
        v-model:result="testResult"
        :index="openStepIndex"
        :tool-id="toolId"
        :agent-name="agentName"
        :errors="serverErrors"
        @move="move"
        @remove="deleteStep"
        @close="openStepIndex = null"
      />
    </template>
  </PageLayout>
</template>

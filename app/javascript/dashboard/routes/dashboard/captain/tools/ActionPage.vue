<script setup>
import { computed, onMounted, reactive, ref, watch, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import { onBeforeRouteLeave, useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import CustomToolsAPI from 'dashboard/api/captain/customTools';

import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import RadioCard from 'dashboard/components-next/radioCard/RadioCard.vue';
import ParamRow from 'dashboard/components-next/captain/pageComponents/customTool/ParamRow.vue';
import AuthConfig from 'dashboard/components-next/captain/pageComponents/customTool/AuthConfig.vue';
import StepCard from 'dashboard/components-next/captain/pageComponents/customTool/action/StepCard.vue';
import OutputsTable from 'dashboard/components-next/captain/pageComponents/customTool/action/OutputsTable.vue';
import TestPanel from 'dashboard/components-next/captain/pageComponents/customTool/action/TestPanel.vue';
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

const toolId = computed(() =>
  route.params.toolId ? Number(route.params.toolId) : null
);
const form = reactive(fromTool());
const isLoading = ref(!!toolId.value);
const isSaving = ref(false);
const savedSnapshot = ref('');
const serverErrors = ref({});
const titleError = ref('');
const focusedOutputKey = ref('');
const modeTouched = ref(!!toolId.value);

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
const stepVariables = index => variablesBefore(form, index);
const stepErrors = step => serverErrors.value[`steps.${step.key}`] || [];
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

const addStep = type => form.steps.push(newStep(type, form.steps));
const move = (index, offset) => {
  form.steps = moveStep(form.steps, index, offset);
};
const deleteStep = index => {
  Object.assign(form, removeStep(form.steps, form.outputs, index));
};

const addOutput = output => {
  form.outputs.push(output);
  focusedOutputKey.value = output.key;
};
const focusOutput = async key => {
  focusedOutputKey.value = key;
  await nextTick();
  document
    .querySelector(`[data-output-key="${key}"]`)
    ?.scrollIntoView({ behavior: 'smooth', block: 'center' });
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
    addStep('request');
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
    container-class="max-w-[80rem]"
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
      <div
        class="grid gap-6 pb-10 lg:grid-cols-[minmax(0,1fr)_minmax(0,26rem)]"
      >
        <form class="flex flex-col min-w-0 gap-8" @submit.prevent="save">
          <section class="flex flex-col gap-3">
            <Input
              v-model="form.title"
              :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.NAME.LABEL')"
              :placeholder="t('CAPTAIN.CUSTOM_TOOLS.ACTION.NAME.PLACEHOLDER')"
              :message="titleError"
              :message-type="titleError ? 'error' : 'info'"
            />
            <TextArea
              v-model="form.description"
              :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.WHEN.LABEL')"
              :placeholder="t('CAPTAIN.CUSTOM_TOOLS.ACTION.WHEN.PLACEHOLDER')"
              :rows="3"
            />
            <p class="-mt-1 mb-0 text-xs text-n-slate-11">
              {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.WHEN.HELP') }}
            </p>
          </section>

          <section class="flex flex-col gap-2">
            <h2 class="mb-0 text-base font-medium text-n-slate-12">
              {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.INPUTS.TITLE') }}
            </h2>
            <p class="mb-0 text-xs text-n-slate-11">
              {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.INPUTS.HELP') }}
            </p>
            <ul v-if="form.param_schema.length" class="grid gap-2 list-none">
              <ParamRow
                v-for="(param, index) in form.param_schema"
                :key="index"
                v-model:name="param.name"
                v-model:type="param.type"
                v-model:description="param.description"
                v-model:required="param.required"
                v-model:test-value="param.test_value"
                @remove="form.param_schema.splice(index, 1)"
              />
            </ul>
            <Button
              type="button"
              size="sm"
              variant="ghost"
              color="blue"
              icon="i-lucide-plus"
              class="self-start"
              :label="t('CAPTAIN.CUSTOM_TOOLS.FORM.ADD_PARAMETER')"
              @click="addParam"
            />
          </section>

          <section class="flex flex-col gap-2">
            <h2 class="mb-0 text-base font-medium text-n-slate-12">
              {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.CONNECTION.TITLE') }}
            </h2>
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
          </section>

          <section class="flex flex-col gap-2">
            <h2 class="mb-0 text-base font-medium text-n-slate-12">
              {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.TITLE') }}
            </h2>
            <p class="mb-0 text-xs text-n-slate-11">
              {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.HELP') }}
            </p>
            <ul class="flex flex-col gap-3 mb-0 list-none">
              <StepCard
                v-for="(step, index) in form.steps"
                :key="index"
                v-model:step="form.steps[index]"
                :index="index"
                :total="form.steps.length"
                :variables="stepVariables(index)"
                :errors="stepErrors(step)"
                @move-up="move(index, -1)"
                @move-down="move(index, 1)"
                @remove="deleteStep(index)"
              />
            </ul>
            <ul
              v-if="generalErrors.length"
              class="mb-0 text-sm list-none text-n-ruby-11"
            >
              <li v-for="error in generalErrors" :key="error">{{ error }}</li>
            </ul>
            <div class="flex gap-2">
              <Button
                type="button"
                size="sm"
                variant="faded"
                color="slate"
                icon="i-lucide-globe"
                :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.ADD_REQUEST')"
                :disabled="!canAddStep('request', form.steps)"
                @click="addStep('request')"
              />
              <Button
                type="button"
                size="sm"
                variant="faded"
                color="slate"
                icon="i-lucide-shield-check"
                :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.ADD_VERIFY')"
                :disabled="!canAddStep('verify', form.steps)"
                @click="addStep('verify')"
              />
            </div>
          </section>

          <section class="flex flex-col gap-2">
            <h2 class="mb-0 text-base font-medium text-n-slate-12">
              {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.OUTPUTS.TITLE') }}
            </h2>
            <p class="mb-0 text-xs text-n-slate-11">
              {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.OUTPUTS.HELP') }}
            </p>
            <OutputsTable
              v-model:outputs="form.outputs"
              :focused-key="focusedOutputKey"
              :errors="serverErrors"
            />
            <TextArea
              v-model="form.response_template"
              :label="t('CAPTAIN.CUSTOM_TOOLS.FORM.RESPONSE_TEMPLATE.LABEL')"
              :placeholder="
                t('CAPTAIN.CUSTOM_TOOLS.ACTION.OUTPUTS.TEMPLATE_PLACEHOLDER')
              "
              :rows="2"
              class="[&_textarea]:font-mono"
            />
          </section>

          <section class="flex flex-col gap-3">
            <h2 class="mb-0 text-base font-medium text-n-slate-12">
              {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.MODE.TITLE') }}
            </h2>
            <div class="grid gap-3 md:grid-cols-2">
              <RadioCard
                id="action-mode-background"
                name="execution_mode"
                :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.MODE.BACKGROUND')"
                :description="
                  t('CAPTAIN.CUSTOM_TOOLS.ACTION.MODE.BACKGROUND_HELP')
                "
                :is-active="form.execution_mode === 'background'"
                @select="selectMode('background')"
              />
              <RadioCard
                id="action-mode-confirm"
                name="execution_mode"
                :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.MODE.CONFIRM')"
                :description="
                  t('CAPTAIN.CUSTOM_TOOLS.ACTION.MODE.CONFIRM_HELP')
                "
                :is-active="form.execution_mode === 'confirm'"
                @select="selectMode('confirm')"
              />
            </div>
            <template v-if="form.execution_mode === 'confirm'">
              <div
                v-for="key in ['confirm_prompt', 'success', 'failure']"
                :key="key"
                class="flex items-start gap-2"
              >
                <TextArea
                  v-model="form.messages[key]"
                  :label="
                    t(`CAPTAIN.CUSTOM_TOOLS.ACTION.MODE.${key.toUpperCase()}`)
                  "
                  :placeholder="
                    t(
                      `CAPTAIN.CUSTOM_TOOLS.ACTION.MODE.${key.toUpperCase()}_PLACEHOLDER`
                    )
                  "
                  :rows="2"
                  class="flex-1"
                />
                <VariablePicker
                  class="mt-7"
                  :variables="allOutputs"
                  @insert="text => appendMessage(key, text)"
                />
              </div>
              <div class="flex flex-col gap-2 p-4 rounded-xl bg-n-alpha-1">
                <span class="text-xs text-n-slate-11">
                  {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.MODE.PREVIEW') }}
                </span>
                <p
                  class="self-start px-3 py-2 mb-0 text-sm rounded-xl bg-n-solid-2 text-n-slate-12"
                >
                  {{ confirmPreview }}
                </p>
                <div class="flex gap-2">
                  <span
                    class="px-3 py-1 text-sm rounded-lg outline outline-1 outline-n-weak text-n-blue-11"
                  >
                    {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.MODE.CONFIRM_BUTTON') }}
                  </span>
                  <span
                    class="px-3 py-1 text-sm rounded-lg outline outline-1 outline-n-weak text-n-slate-11"
                  >
                    {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.MODE.CANCEL_BUTTON') }}
                  </span>
                </div>
                <p class="mb-0 text-xs text-n-slate-10">
                  {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.MODE.CHANNEL_NOTE') }}
                </p>
              </div>
            </template>
          </section>
        </form>

        <aside class="min-w-0 lg:sticky lg:top-0 lg:self-start">
          <TestPanel
            :form="form"
            :tool-id="toolId"
            @add-output="addOutput"
            @focus-output="focusOutput"
          />
        </aside>
      </div>
    </template>
  </PageLayout>
</template>

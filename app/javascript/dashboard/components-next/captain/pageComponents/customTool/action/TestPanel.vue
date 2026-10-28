<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import CustomToolsAPI from 'dashboard/api/captain/customTools';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import JsonTree from './JsonTree.vue';
import {
  everyItemSegments,
  lastIndexPosition,
  outputFromPick,
  pathFromSegments,
  toPayload,
} from './actionForm';

// Runs the action up to one step and shows that step's response. Clicking a field saves it as an output.
const props = defineProps({
  stepKey: { type: String, required: true },
  toolId: { type: Number, default: null },
});

const emit = defineEmits(['addOutput', 'focusOutput']);
const form = defineModel('form', { type: Object, required: true });
// The last run, shared with the step list so it can show which steps passed.
const result = defineModel('result', { type: Object, default: null });
const { t } = useI18n();

const isRunning = ref(false);
const runError = ref('');
const showChangeWarning = ref(false);
const pendingPick = ref(null); // an array item click waiting for "this item" or "every item"

const namedParams = computed(() =>
  form.value.param_schema.filter(param => param.name)
);
const stepsUpToHere = computed(() => {
  const last = form.value.steps.findIndex(step => step.key === props.stepKey);
  return form.value.steps.slice(0, last + 1);
});
const changesData = computed(() =>
  stepsUpToHere.value.some(
    step => step.type === 'request' && step.method !== 'GET'
  )
);
const stepResult = computed(() =>
  result.value?.steps?.find(step => step.key === props.stepKey)
);
// When an earlier step failed, this step never ran.
const earlierFailure = computed(() => {
  if (!result.value || stepResult.value) return null;
  return result.value.steps?.find(step => !step.ok) || null;
});
const savedPaths = computed(() =>
  form.value.outputs
    .filter(output => output.step === props.stepKey)
    .map(output => output.path)
);
const hasTree = computed(
  () =>
    stepResult.value?.response && typeof stepResult.value.response === 'object'
);

const execute = async () => {
  showChangeWarning.value = false;
  isRunning.value = true;
  runError.value = '';
  try {
    const { data } = await CustomToolsAPI.test(toPayload(form.value), {
      id: props.toolId,
      stop_after: props.stepKey,
    });
    result.value = data;
  } catch (error) {
    result.value = null;
    runError.value =
      error.response?.data?.message ||
      error.response?.data?.error ||
      t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.ERROR');
  } finally {
    isRunning.value = false;
  }
};

const run = () => {
  if (changesData.value) {
    showChangeWarning.value = true;
    return;
  }
  execute();
};

const pickEveryItem = () => {
  const segments = everyItemSegments(pendingPick.value.segments);
  pendingPick.value = null;
  emit(
    'addOutput',
    outputFromPick({ stepKey: props.stepKey, segments }, form.value.outputs)
  );
};

const handlePick = ({ segments, value }) => {
  const saved = form.value.outputs.find(
    output =>
      output.step === props.stepKey &&
      output.path === pathFromSegments(segments)
  );
  if (saved) {
    emit('focusOutput', saved.key);
    return;
  }
  if (lastIndexPosition(segments) !== -1) {
    pendingPick.value = { segments, value };
    return;
  }
  emit(
    'addOutput',
    outputFromPick(
      { stepKey: props.stepKey, segments, value },
      form.value.outputs
    )
  );
};

const pickThisItem = () => {
  const { segments, value } = pendingPick.value;
  pendingPick.value = null;
  emit(
    'addOutput',
    outputFromPick(
      { stepKey: props.stepKey, segments, value },
      form.value.outputs
    )
  );
};

const pickItemLabel = computed(() => {
  if (!pendingPick.value) return '';
  const { segments } = pendingPick.value;
  return `[${segments[lastIndexPosition(segments)]}]`;
});
</script>

<template>
  <div class="flex flex-col gap-4">
    <div v-if="namedParams.length" class="flex flex-col gap-2">
      <span class="text-xs font-medium text-n-slate-11">
        {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.VALUES') }}
      </span>
      <div
        v-for="param in namedParams"
        :key="param.name"
        class="grid items-center grid-cols-[minmax(0,8rem)_minmax(0,1fr)] gap-2"
      >
        <span class="font-mono text-xs truncate text-n-slate-11">
          {{ param.name }}
        </span>
        <Input
          v-model="param.test_value"
          custom-input-class="!h-8 text-sm"
          :aria-label="param.name"
        />
      </div>
    </div>

    <Button
      type="button"
      size="sm"
      icon="i-lucide-play"
      class="self-start"
      :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.RUN')"
      :is-loading="isRunning"
      :disabled="isRunning"
      data-test="run-test"
      @click="run"
    />

    <div
      v-if="showChangeWarning"
      class="flex flex-col gap-2 p-3 text-sm rounded-lg bg-n-amber-2 text-n-amber-11"
      data-test="change-warning"
    >
      <span>{{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.CHANGE_WARNING') }}</span>
      <div class="flex gap-2">
        <Button
          type="button"
          size="xs"
          color="amber"
          :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.RUN_ANYWAY')"
          @click="execute"
        />
        <Button
          type="button"
          size="xs"
          variant="ghost"
          color="slate"
          :label="t('CAPTAIN.FORM.CANCEL')"
          @click="showChangeWarning = false"
        />
      </div>
    </div>

    <p v-if="runError" class="mb-0 text-sm text-n-ruby-11">{{ runError }}</p>
    <p v-if="earlierFailure" class="mb-0 text-sm text-n-ruby-11">
      {{
        t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.EARLIER_FAILED', {
          error: earlierFailure.error || earlierFailure.status,
        })
      }}
    </p>

    <template v-if="stepResult">
      <div class="flex flex-wrap items-center gap-2 text-xs">
        <span
          class="px-2 py-0.5 rounded-full"
          :class="
            stepResult.ok
              ? 'bg-n-teal-3 text-n-teal-11'
              : 'bg-n-ruby-3 text-n-ruby-11'
          "
        >
          {{
            stepResult.status ||
            (stepResult.ok
              ? t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.PASSED')
              : t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.FAILED'))
          }}
        </span>
        <span v-if="stepResult.duration_ms != null" class="text-n-slate-10">
          {{
            t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.DURATION', {
              ms: stepResult.duration_ms,
            })
          }}
        </span>
        <span
          v-if="stepResult.request"
          class="min-w-0 font-mono break-all text-n-slate-10"
        >
          {{ stepResult.request.url }}
        </span>
      </div>
      <p v-if="stepResult.error" class="mb-0 text-sm text-n-ruby-11">
        {{ stepResult.error }}
      </p>
      <p v-if="stepResult.missing_outputs" class="mb-0 text-sm text-n-ruby-11">
        {{
          t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.MISSING', {
            keys: stepResult.missing_outputs.join(', '),
          })
        }}
      </p>
      <p
        v-if="stepResult.compared"
        class="mb-0 font-mono text-xs text-n-slate-11"
      >
        {{
          t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.COMPARED', {
            left: stepResult.compared.left,
            right: stepResult.compared.right,
          })
        }}
      </p>

      <div
        v-if="pendingPick"
        class="flex flex-wrap items-center gap-2 p-3 text-sm rounded-lg bg-n-blue-2 text-n-slate-12"
        data-test="item-choice"
      >
        <span>{{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.ARRAY_CHOICE') }}</span>
        <Button
          type="button"
          size="xs"
          variant="faded"
          :label="
            t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.THIS_ITEM', {
              index: pickItemLabel,
            })
          "
          @click="pickThisItem"
        />
        <Button
          type="button"
          size="xs"
          variant="faded"
          :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.EVERY_ITEM')"
          @click="pickEveryItem"
        />
      </div>

      <template v-if="stepResult.response !== undefined">
        <span v-if="hasTree" class="text-xs text-n-slate-11">
          {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.PICK_HINT') }}
        </span>
        <div
          v-if="hasTree"
          class="p-2 overflow-auto rounded-lg max-h-96 bg-n-alpha-1"
        >
          <JsonTree
            :value="stepResult.response"
            :saved-paths="savedPaths"
            @pick="handlePick"
          />
        </div>
        <pre
          v-else
          class="p-2 mb-0 overflow-auto text-xs whitespace-pre-wrap rounded-lg max-h-60 bg-n-alpha-1"
          >{{ stepResult.response }}</pre
        >
      </template>
    </template>
  </div>
</template>

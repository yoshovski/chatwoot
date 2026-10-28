<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import CustomToolsAPI from 'dashboard/api/captain/customTools';
import Button from 'dashboard/components-next/button/Button.vue';
import JsonTree from './JsonTree.vue';
import {
  everyItemSegments,
  lastIndexPosition,
  outputFromPick,
  pathFromSegments,
  toPayload,
} from './actionForm';

const props = defineProps({
  form: { type: Object, required: true },
  toolId: { type: Number, default: null },
});

const emit = defineEmits(['addOutput', 'focusOutput']);
const { t } = useI18n();

const isRunning = ref(false);
const result = ref(null);
const runError = ref('');
const pendingRun = ref(null); // { stopAfter } waiting for the non-GET warning
const pendingPick = ref(null); // an array item click waiting for "this item" or "every item"

const savedPaths = stepKey =>
  props.form.outputs
    .filter(output => output.step === stepKey)
    .map(output => output.path);

const stepsUpTo = stopAfter => {
  const last = props.form.steps.findIndex(step => step.key === stopAfter);
  return last === -1 ? props.form.steps : props.form.steps.slice(0, last + 1);
};

const changesData = stopAfter =>
  stepsUpTo(stopAfter).some(
    step => step.type === 'request' && step.method !== 'GET'
  );

const execute = async stopAfter => {
  pendingRun.value = null;
  isRunning.value = true;
  runError.value = '';
  try {
    const { data } = await CustomToolsAPI.test(toPayload(props.form), {
      id: props.toolId,
      stop_after: stopAfter,
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

const run = (stopAfter = null) => {
  if (changesData(stopAfter)) {
    pendingRun.value = { stopAfter };
    return;
  }
  execute(stopAfter);
};

const addOutput = (stepKey, segments, value) => {
  pendingPick.value = null;
  emit(
    'addOutput',
    outputFromPick({ stepKey, segments, value }, props.form.outputs)
  );
};

const handlePick = (stepKey, { segments, value }) => {
  const saved = props.form.outputs.find(
    output =>
      output.step === stepKey && output.path === pathFromSegments(segments)
  );
  if (saved) {
    emit('focusOutput', saved.key);
    return;
  }
  if (lastIndexPosition(segments) !== -1) {
    pendingPick.value = { stepKey, segments, value };
    return;
  }
  addOutput(stepKey, segments, value);
};

const pickItemLabel = computed(() => {
  if (!pendingPick.value) return '';
  const { segments } = pendingPick.value;
  return `[${segments[lastIndexPosition(segments)]}]`;
});

const statusClass = step =>
  step.ok ? 'bg-n-teal-3 text-n-teal-11' : 'bg-n-ruby-3 text-n-ruby-11';

const hasOutputs = computed(
  () => result.value && Object.keys(result.value.outputs || {}).length > 0
);
</script>

<template>
  <div
    class="flex flex-col gap-3 p-4 rounded-xl outline outline-1 outline-n-weak bg-n-solid-1"
  >
    <div class="flex items-center justify-between gap-2">
      <h3 class="mb-0 text-sm font-medium text-n-slate-12">
        {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.TITLE') }}
      </h3>
      <Button
        type="button"
        size="sm"
        icon="i-lucide-play"
        :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.RUN')"
        :is-loading="isRunning"
        :disabled="isRunning || !form.steps.length"
        @click="run()"
      />
    </div>
    <p class="mb-0 text-xs text-n-slate-11">
      {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.HELP') }}
    </p>

    <div v-if="form.steps.length > 1" class="flex flex-wrap gap-1">
      <Button
        v-for="step in form.steps"
        :key="step.key"
        type="button"
        size="xs"
        variant="faded"
        color="slate"
        :label="
          t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.RUN_UP_TO', { key: step.key })
        "
        :disabled="isRunning"
        @click="run(step.key)"
      />
    </div>

    <div
      v-if="pendingRun"
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
          @click="execute(pendingRun.stopAfter)"
        />
        <Button
          type="button"
          size="xs"
          variant="ghost"
          color="slate"
          :label="t('CAPTAIN.FORM.CANCEL')"
          @click="pendingRun = null"
        />
      </div>
    </div>

    <p v-if="runError" class="mb-0 text-sm text-n-ruby-11">{{ runError }}</p>

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
        data-test="this-item"
        @click="
          addOutput(
            pendingPick.stepKey,
            pendingPick.segments,
            pendingPick.value
          )
        "
      />
      <Button
        type="button"
        size="xs"
        variant="faded"
        :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.EVERY_ITEM')"
        data-test="every-item"
        @click="
          addOutput(
            pendingPick.stepKey,
            everyItemSegments(pendingPick.segments),
            pendingPick.value
          )
        "
      />
    </div>

    <template v-if="result">
      <div
        v-for="step in result.steps"
        :key="step.key"
        class="flex flex-col gap-2 pt-3 border-t border-n-weak"
      >
        <div class="flex items-center gap-2 text-xs">
          <span class="px-2 py-0.5 rounded-full" :class="statusClass(step)">
            {{
              step.status ||
              (step.ok
                ? t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.PASSED')
                : t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.FAILED'))
            }}
          </span>
          <span class="font-mono text-n-slate-12">{{ step.key }}</span>
          <span v-if="step.duration_ms != null" class="text-n-slate-10">
            {{
              t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.DURATION', {
                ms: step.duration_ms,
              })
            }}
          </span>
        </div>
        <p
          v-if="step.request"
          class="mb-0 font-mono text-xs break-all text-n-slate-11"
        >
          {{ step.request.method }} {{ step.request.url }}
        </p>
        <p v-if="step.error" class="mb-0 text-xs text-n-ruby-11">
          {{ step.error }}
        </p>
        <p v-if="step.missing_outputs" class="mb-0 text-xs text-n-ruby-11">
          {{
            t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.MISSING', {
              keys: step.missing_outputs.join(', '),
            })
          }}
        </p>
        <p v-if="step.compared" class="mb-0 font-mono text-xs text-n-slate-11">
          {{
            t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.COMPARED', {
              left: step.compared.left,
              right: step.compared.right,
            })
          }}
        </p>
        <div
          v-if="
            step.response !== undefined && typeof step.response === 'object'
          "
          class="p-2 overflow-auto rounded-lg max-h-80 bg-n-alpha-1"
        >
          <JsonTree
            :value="step.response"
            :saved-paths="savedPaths(step.key)"
            @pick="payload => handlePick(step.key, payload)"
          />
        </div>
        <pre
          v-else-if="step.response !== undefined"
          class="p-2 mb-0 overflow-auto text-xs whitespace-pre-wrap rounded-lg max-h-60 bg-n-alpha-1"
          >{{ step.response }}</pre
        >
      </div>

      <div class="flex flex-col gap-1 pt-3 border-t border-n-weak">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.OUTPUTS') }}
        </span>
        <pre
          v-if="hasOutputs"
          class="p-2 mb-0 overflow-auto text-xs rounded-lg bg-n-alpha-1"
          >{{ JSON.stringify(result.outputs, null, 2) }}</pre
        >
        <p v-else class="mb-0 text-xs text-n-slate-10">
          {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.TEST.NO_OUTPUTS') }}
        </p>
      </div>
    </template>
  </div>
</template>

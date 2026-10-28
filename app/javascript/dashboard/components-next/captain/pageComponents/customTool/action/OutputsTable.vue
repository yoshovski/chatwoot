<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import { OUTPUT_TYPES } from './actionForm';

// The outputs saved from one step's response.
const props = defineProps({
  stepKey: { type: String, required: true },
  agentName: { type: String, required: true },
  focusedKey: { type: String, default: '' },
  errors: { type: Object, default: () => ({}) },
});

const outputs = defineModel('outputs', { type: Array, required: true });
const { t } = useI18n();

const typeOptions = OUTPUT_TYPES.map(type => ({ value: type, label: type }));
const stepOutputs = computed(() =>
  outputs.value.filter(output => output.step === props.stepKey)
);
const remove = output => outputs.value.splice(outputs.value.indexOf(output), 1);
const errorFor = output =>
  (props.errors[`outputs.${output.key}`] || []).join(', ');
</script>

<template>
  <p v-if="!stepOutputs.length" class="mb-0 text-sm text-n-slate-10">
    {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.OUTPUTS.EMPTY') }}
  </p>
  <ul v-else class="flex flex-col gap-2 mb-0 list-none">
    <li
      v-for="output in stepOutputs"
      :key="outputs.indexOf(output)"
      class="flex flex-col gap-2 p-3 rounded-lg bg-n-alpha-1"
      :class="{
        'outline outline-1 outline-n-blue-8': output.key === focusedKey,
      }"
      :data-output-key="output.key"
    >
      <div class="flex items-center gap-2">
        <Input
          v-model="output.key"
          custom-input-class="font-mono !h-8 text-xs"
          class="flex-1 min-w-0"
          :aria-label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.OUTPUTS.KEY')"
          :message="errorFor(output)"
          :message-type="errorFor(output) ? 'error' : 'info'"
        />
        <div class="w-24 shrink-0">
          <ComboBox
            v-model="output.type"
            :options="typeOptions"
            class="[&>div>button]:bg-n-alpha-black2 [&>div>button]:!py-1.5"
          />
        </div>
        <Button
          type="button"
          size="xs"
          variant="ghost"
          color="slate"
          icon="i-lucide-trash"
          :aria-label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.OUTPUTS.REMOVE')"
          @click="remove(output)"
        />
      </div>
      <div class="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs">
        <span class="font-mono break-all text-n-slate-10">
          {{ output.path }}
        </span>
        <label class="flex items-center gap-1.5 text-n-slate-11 ms-auto">
          <Switch v-model="output.available_to_ai" />
          {{
            t('CAPTAIN.CUSTOM_TOOLS.ACTION.OUTPUTS.AI_VISIBLE', {
              agent: agentName,
            })
          }}
        </label>
        <label class="flex items-center gap-1.5 text-n-slate-11">
          <Switch v-model="output.required" />
          {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.OUTPUTS.REQUIRED') }}
        </label>
      </div>
    </li>
  </ul>
</template>

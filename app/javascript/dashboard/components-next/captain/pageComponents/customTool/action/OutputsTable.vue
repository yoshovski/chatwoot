<script setup>
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import { OUTPUT_TYPES } from './actionForm';

defineProps({
  focusedKey: { type: String, default: '' },
  errors: { type: Object, default: () => ({}) },
});

const outputs = defineModel('outputs', { type: Array, required: true });
const { t } = useI18n();

const typeOptions = OUTPUT_TYPES.map(type => ({ value: type, label: type }));
const remove = position => outputs.value.splice(position, 1);
</script>

<template>
  <p
    v-if="!outputs.length"
    class="p-4 mb-0 text-sm text-center rounded-xl bg-n-alpha-1 text-n-slate-11"
  >
    {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.OUTPUTS.EMPTY') }}
  </p>
  <div v-else class="overflow-x-auto">
    <table class="w-full text-sm">
      <thead>
        <tr class="text-xs text-start text-n-slate-11">
          <th class="py-1 font-medium text-start">
            {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.OUTPUTS.KEY') }}
          </th>
          <th class="py-1 font-medium text-start">
            {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.OUTPUTS.SOURCE') }}
          </th>
          <th class="py-1 font-medium text-start">
            {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.OUTPUTS.TYPE') }}
          </th>
          <th class="py-1 font-medium text-center">
            {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.OUTPUTS.AI_VISIBLE') }}
          </th>
          <th class="py-1 font-medium text-center">
            {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.OUTPUTS.REQUIRED') }}
          </th>
          <th />
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="(output, position) in outputs"
          :key="position"
          class="align-top"
          :class="{ 'bg-n-blue-2': output.key === focusedKey }"
          :data-output-key="output.key"
        >
          <td class="py-1 pe-2">
            <Input
              v-model="output.key"
              custom-input-class="font-mono !h-8 text-xs"
              :message="(errors[`outputs.${output.key}`] || []).join(', ')"
              :message-type="errors[`outputs.${output.key}`] ? 'error' : 'info'"
            />
          </td>
          <td class="py-1 font-mono text-xs break-all pe-2 text-n-slate-11">
            {{ output.step }} · {{ output.path }}
          </td>
          <td class="w-28 py-1 pe-2">
            <ComboBox
              v-model="output.type"
              :options="typeOptions"
              class="[&>div>button]:bg-n-alpha-black2"
            />
          </td>
          <td class="py-2 text-center">
            <Checkbox v-model="output.available_to_ai" />
          </td>
          <td class="py-2 text-center">
            <Checkbox v-model="output.required" />
          </td>
          <td class="py-1">
            <Button
              type="button"
              size="xs"
              variant="ghost"
              color="slate"
              icon="i-lucide-trash"
              :aria-label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.OUTPUTS.REMOVE')"
              @click="remove(position)"
            />
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

// One thing the AI asks the customer for, on a single line.
const emit = defineEmits(['remove']);
const { t } = useI18n();

const name = defineModel('name', { type: String, required: true });
const type = defineModel('type', { type: String, required: true });
const description = defineModel('description', { type: String, default: '' });
const required = defineModel('required', { type: Boolean, default: false });

const paramTypeOptions = computed(() =>
  ['string', 'number', 'boolean', 'array', 'object'].map(value => ({
    value,
    label: t(`CAPTAIN.CUSTOM_TOOLS.FORM.PARAM_TYPES.${value.toUpperCase()}`),
  }))
);
</script>

<template>
  <li class="flex flex-wrap items-center gap-2 list-none">
    <Input
      v-model="name"
      :placeholder="t('CAPTAIN.CUSTOM_TOOLS.FORM.PARAM_NAME.PLACEHOLDER')"
      :aria-label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.INPUTS.NAME')"
      custom-input-class="font-mono !h-8 text-sm"
      class="w-40 shrink-0"
    />
    <Input
      v-model="description"
      :placeholder="
        t('CAPTAIN.CUSTOM_TOOLS.FORM.PARAM_DESCRIPTION.PLACEHOLDER')
      "
      :aria-label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.INPUTS.DESCRIPTION')"
      custom-input-class="!h-8 text-sm"
      class="flex-1 min-w-[12rem]"
    />
    <div class="flex items-center gap-3 ms-auto shrink-0">
      <div class="w-28">
        <ComboBox
          v-model="type"
          :options="paramTypeOptions"
          class="[&>div>button]:bg-n-alpha-black2 [&>div>button]:!py-1.5"
        />
      </div>
      <label
        class="flex items-center gap-1.5 text-xs text-n-slate-11 whitespace-nowrap"
      >
        <Switch v-model="required" />
        {{ t('CAPTAIN.CUSTOM_TOOLS.FORM.PARAM_REQUIRED.LABEL') }}
      </label>
      <Button
        type="button"
        size="xs"
        variant="ghost"
        color="slate"
        icon="i-lucide-x"
        :aria-label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.INPUTS.REMOVE')"
        @click="emit('remove')"
      />
    </div>
  </li>
</template>

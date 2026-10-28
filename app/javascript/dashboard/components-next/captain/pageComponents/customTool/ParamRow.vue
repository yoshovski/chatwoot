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
  <li
    class="grid items-center gap-2 list-none grid-cols-[minmax(0,1fr)_auto] md:grid-cols-[minmax(0,10rem)_minmax(0,1fr)_7rem_auto_auto]"
  >
    <Input
      v-model="name"
      :placeholder="t('CAPTAIN.CUSTOM_TOOLS.FORM.PARAM_NAME.PLACEHOLDER')"
      :aria-label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.INPUTS.NAME')"
      custom-input-class="font-mono !h-8 text-sm"
    />
    <Button
      type="button"
      size="xs"
      variant="ghost"
      color="slate"
      icon="i-lucide-x"
      class="md:order-last"
      :aria-label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.INPUTS.REMOVE')"
      @click="emit('remove')"
    />
    <Input
      v-model="description"
      :placeholder="
        t('CAPTAIN.CUSTOM_TOOLS.FORM.PARAM_DESCRIPTION.PLACEHOLDER')
      "
      :aria-label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.INPUTS.DESCRIPTION')"
      custom-input-class="!h-8 text-sm"
      class="col-span-2 md:col-span-1"
    />
    <div class="flex items-center col-span-2 gap-4 md:contents">
      <div class="w-28 md:w-auto">
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
    </div>
  </li>
</template>

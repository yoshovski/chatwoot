<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import VariablePicker from './VariablePicker.vue';
import { COMPARISONS, REQUEST_METHODS } from './actionForm';

defineProps({
  index: { type: Number, required: true },
  total: { type: Number, required: true },
  variables: { type: Object, required: true },
  errors: { type: Array, default: () => [] },
});

const emit = defineEmits(['moveUp', 'moveDown', 'remove']);

const step = defineModel('step', { type: Object, required: true });

const { t } = useI18n();

const isRequest = computed(() => step.value.type === 'request');
const sendsBody = computed(
  () => isRequest.value && step.value.method !== 'GET'
);

const methodOptions = REQUEST_METHODS.map(method => ({
  value: method,
  label: method,
}));
const bodyTypeOptions = computed(() => [
  {
    value: 'json',
    label: t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.BODY_TYPES.JSON'),
  },
  {
    value: 'text',
    label: t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.BODY_TYPES.TEXT'),
  },
]);
const compareOptions = computed(() =>
  COMPARISONS.map(compare => ({
    value: compare,
    label: t(
      `CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.COMPARISONS.${compare.toUpperCase()}`
    ),
  }))
);

const verifyPreview = computed(() =>
  t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.VERIFY_PREVIEW', {
    left: step.value.left || '…',
    right: step.value.right || '…',
    comparison: t(
      `CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.COMPARISONS.${(step.value.compare || 'exact').toUpperCase()}`
    ),
  })
);

const append = (field, text) => {
  step.value[field] = `${step.value[field] || ''}${text}`;
};

const appendHeader = (header, text) => {
  header.value = `${header.value || ''}${text}`;
};

const addHeader = () => step.value.headers.push({ name: '', value: '' });
const removeHeader = position => step.value.headers.splice(position, 1);
</script>

<template>
  <li
    class="flex flex-col gap-3 p-4 list-none rounded-xl outline outline-1 bg-n-solid-1"
    :class="errors.length ? 'outline-n-ruby-8' : 'outline-n-weak'"
  >
    <div class="flex items-center justify-between gap-2">
      <div class="flex items-center gap-2 min-w-0">
        <span
          class="flex items-center justify-center text-xs font-medium rounded-full size-6 shrink-0 bg-n-alpha-2 text-n-slate-11"
        >
          {{ index + 1 }}
        </span>
        <span class="text-sm font-medium text-n-slate-12">
          {{
            isRequest
              ? t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.REQUEST')
              : t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.VERIFY')
          }}
        </span>
        <Input
          v-model="step.key"
          :aria-label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.KEY')"
          custom-input-class="font-mono !h-7 text-xs"
          class="w-36"
        />
      </div>
      <div class="flex items-center gap-1">
        <Button
          type="button"
          size="xs"
          variant="ghost"
          color="slate"
          icon="i-lucide-arrow-up"
          :disabled="index === 0"
          :aria-label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.MOVE_UP')"
          @click="emit('moveUp')"
        />
        <Button
          type="button"
          size="xs"
          variant="ghost"
          color="slate"
          icon="i-lucide-arrow-down"
          :disabled="index === total - 1"
          :aria-label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.MOVE_DOWN')"
          @click="emit('moveDown')"
        />
        <Button
          type="button"
          size="xs"
          variant="ghost"
          color="ruby"
          icon="i-lucide-trash"
          :aria-label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.REMOVE')"
          @click="emit('remove')"
        />
      </div>
    </div>

    <template v-if="isRequest">
      <div class="flex items-end gap-2">
        <ComboBox
          v-model="step.method"
          :options="methodOptions"
          class="w-28 shrink-0 [&_button]:font-mono [&_li]:font-mono [&>div>button]:bg-n-alpha-black2"
        />
        <Input
          v-model="step.url"
          :placeholder="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.URL_PLACEHOLDER')"
          custom-input-class="font-mono"
          class="flex-1 min-w-0"
        />
        <VariablePicker
          :variables="variables"
          @insert="text => append('url', text)"
        />
      </div>

      <div class="flex flex-col gap-2">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.HEADERS') }}
        </span>
        <div
          v-for="(header, position) in step.headers"
          :key="position"
          class="flex items-center gap-2"
        >
          <Input
            v-model="header.name"
            :placeholder="
              t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.HEADER_NAME_PLACEHOLDER')
            "
            custom-input-class="font-mono"
            class="w-40 shrink-0"
          />
          <Input
            v-model="header.value"
            :placeholder="
              t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.HEADER_VALUE_PLACEHOLDER')
            "
            custom-input-class="font-mono"
            class="flex-1 min-w-0"
          />
          <VariablePicker
            :variables="variables"
            @insert="text => appendHeader(header, text)"
          />
          <Button
            type="button"
            size="xs"
            variant="ghost"
            color="slate"
            icon="i-lucide-x"
            :aria-label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.REMOVE_HEADER')"
            @click="removeHeader(position)"
          />
        </div>
        <Button
          type="button"
          size="xs"
          variant="ghost"
          color="blue"
          icon="i-lucide-plus"
          class="self-start"
          :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.ADD_HEADER')"
          @click="addHeader"
        />
      </div>

      <div v-if="sendsBody" class="flex flex-col gap-2">
        <div class="flex items-center justify-between gap-2">
          <ComboBox
            v-model="step.body_type"
            :options="bodyTypeOptions"
            class="w-32 [&>div>button]:bg-n-alpha-black2"
          />
          <VariablePicker
            :variables="variables"
            @insert="text => append('body', text)"
          />
        </div>
        <TextArea
          v-model="step.body"
          :placeholder="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.BODY_PLACEHOLDER')"
          :rows="4"
          class="[&_textarea]:font-mono"
        />
      </div>
    </template>

    <template v-else>
      <div class="grid gap-2 md:grid-cols-[1fr_auto_1fr] items-end">
        <div class="flex items-end gap-2">
          <Input
            v-model="step.left"
            :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.LEFT')"
            custom-input-class="font-mono"
            class="flex-1 min-w-0"
          />
          <VariablePicker
            :variables="variables"
            @insert="text => append('left', text)"
          />
        </div>
        <ComboBox
          v-model="step.compare"
          :options="compareOptions"
          class="md:w-44 [&>div>button]:bg-n-alpha-black2"
        />
        <div class="flex items-end gap-2">
          <Input
            v-model="step.right"
            :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.RIGHT')"
            custom-input-class="font-mono"
            class="flex-1 min-w-0"
          />
          <VariablePicker
            :variables="variables"
            @insert="text => append('right', text)"
          />
        </div>
      </div>
      <label class="flex items-center gap-2 cursor-pointer">
        <Checkbox v-model="step.require_verified_contact" />
        <span class="text-sm text-n-slate-11">
          {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.REQUIRE_VERIFIED') }}
        </span>
      </label>
      <p class="mb-0 text-xs text-n-slate-11">{{ verifyPreview }}</p>
    </template>

    <ul v-if="errors.length" class="mb-0 text-sm list-none text-n-ruby-11">
      <li v-for="error in errors" :key="error">{{ error }}</li>
    </ul>
  </li>
</template>

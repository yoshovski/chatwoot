<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import VariablePicker from './VariablePicker.vue';
import StepAuth from './StepAuth.vue';
import { COMPARISONS, REQUEST_METHODS } from './actionForm';

// The fields of one step, shown in the step panel.
defineProps({
  variables: { type: Object, required: true },
  errors: { type: Array, default: () => [] },
  sameAsOptions: { type: Array, default: () => [] },
});

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
  <div class="flex flex-col gap-4">
    <template v-if="isRequest">
      <div class="flex flex-wrap items-center gap-2">
        <div class="w-28 shrink-0">
          <ComboBox
            v-model="step.method"
            :options="methodOptions"
            class="[&_button]:font-mono [&_li]:font-mono [&>div>button]:bg-n-alpha-black2"
          />
        </div>
        <Input
          v-model="step.url"
          :placeholder="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.URL_PLACEHOLDER')"
          custom-input-class="font-mono"
          class="flex-1 min-w-[12rem]"
          data-test="step-url"
        />
        <VariablePicker
          :variables="variables"
          @insert="text => append('url', text)"
        />
      </div>

      <div class="flex flex-col gap-2">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.AUTH.LABEL') }}
        </span>
        <StepAuth
          :key="step.key"
          v-model:auth="step.auth"
          :same-as-options="sameAsOptions"
          :configured="step.auth_configured"
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
            class="w-28 sm:w-36 shrink-0"
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
          <span class="text-xs font-medium text-n-slate-11">
            {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.BODY') }}
          </span>
          <div class="flex items-center gap-2">
            <div class="w-24">
              <ComboBox
                v-model="step.body_type"
                :options="bodyTypeOptions"
                class="[&>div>button]:bg-n-alpha-black2"
              />
            </div>
            <VariablePicker
              :variables="variables"
              @insert="text => append('body', text)"
            />
          </div>
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
      <div class="flex items-end gap-2">
        <Input
          v-model="step.left"
          :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.LEFT')"
          :placeholder="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.LEFT_PLACEHOLDER')"
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
        class="[&>div>button]:bg-n-alpha-black2"
      />
      <div class="flex items-end gap-2">
        <Input
          v-model="step.right"
          :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.RIGHT')"
          :placeholder="
            t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.RIGHT_PLACEHOLDER')
          "
          custom-input-class="font-mono"
          class="flex-1 min-w-0"
        />
        <VariablePicker
          :variables="variables"
          @insert="text => append('right', text)"
        />
      </div>
      <label class="flex items-center gap-2 cursor-pointer">
        <Checkbox v-model="step.require_verified_contact" />
        <span class="text-sm text-n-slate-11">
          {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.REQUIRE_VERIFIED') }}
        </span>
      </label>
      <Input
        v-model="step.failure_message"
        :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.FAILURE_MESSAGE')"
        :placeholder="
          t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.FAILURE_MESSAGE_PLACEHOLDER')
        "
      />
    </template>

    <ul v-if="errors.length" class="mb-0 text-sm list-none text-n-ruby-11">
      <li v-for="error in errors" :key="error">{{ error }}</li>
    </ul>
  </div>
</template>

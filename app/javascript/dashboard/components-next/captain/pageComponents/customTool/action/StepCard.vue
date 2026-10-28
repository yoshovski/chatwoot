<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import TemplateField from './TemplateField.vue';
import StepAuth from './StepAuth.vue';
import { COMPARISONS, REQUEST_METHODS, UNARY_COMPARISONS } from './actionForm';

// The fields of one step, shown in the step panel.
defineProps({
  variables: { type: Object, required: true },
  errors: { type: Array, default: () => [] },
  sameAsOptions: { type: Array, default: () => [] },
});

const step = defineModel('step', { type: Object, required: true });

const { t } = useI18n();

const BODY_TYPES = ['json', 'text'];

const isRequest = computed(() => step.value.type === 'request');
const sendsBody = computed(
  () => isRequest.value && step.value.method !== 'GET'
);
const hasExpectedValue = computed(
  () => !UNARY_COMPARISONS.includes(step.value.compare)
);

const methodOptions = REQUEST_METHODS.map(method => ({
  value: method,
  label: method,
}));
const compareOptions = computed(() =>
  COMPARISONS.map(compare => ({
    value: compare,
    label: t(
      `CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.COMPARISONS.${compare.toUpperCase()}`
    ),
  }))
);
const rightPlaceholder = computed(() =>
  ['one_of', 'not_one_of'].includes(step.value.compare)
    ? t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.LIST_PLACEHOLDER')
    : t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.RIGHT_PLACEHOLDER')
);

const addHeader = () => step.value.headers.push({ name: '', value: '' });
const removeHeader = position => step.value.headers.splice(position, 1);
</script>

<template>
  <div class="flex flex-col gap-5">
    <template v-if="isRequest">
      <div class="flex flex-wrap items-start gap-2">
        <div class="w-28 shrink-0">
          <ComboBox
            v-model="step.method"
            :options="methodOptions"
            class="[&_button]:font-mono [&_li]:font-mono [&>div>button]:bg-n-alpha-black2"
          />
        </div>
        <TemplateField
          v-model="step.url"
          :variables="variables"
          :placeholder="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.URL_PLACEHOLDER')"
          class="flex-1 min-w-[12rem]"
          data-test="step-url"
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
          class="flex items-start gap-2"
        >
          <Input
            v-model="header.name"
            :placeholder="
              t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.HEADER_NAME_PLACEHOLDER')
            "
            custom-input-class="font-mono"
            class="w-28 sm:w-36 shrink-0"
          />
          <TemplateField
            v-model="header.value"
            :variables="variables"
            :placeholder="
              t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.HEADER_VALUE_PLACEHOLDER')
            "
            class="flex-1"
          />
          <Button
            type="button"
            size="xs"
            variant="ghost"
            color="slate"
            icon="i-lucide-x"
            class="mt-2"
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
          <div
            class="flex p-0.5 rounded-md bg-n-alpha-1"
            role="radiogroup"
            :aria-label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.BODY')"
          >
            <button
              v-for="type in BODY_TYPES"
              :key="type"
              type="button"
              role="radio"
              :aria-checked="(step.body_type || 'json') === type"
              class="px-2 py-0.5 text-xs rounded"
              :class="
                (step.body_type || 'json') === type
                  ? 'bg-n-solid-3 text-n-slate-12 shadow-sm'
                  : 'text-n-slate-11 hover:text-n-slate-12'
              "
              @click="step.body_type = type"
            >
              {{
                t(
                  `CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.BODY_TYPES.${type.toUpperCase()}`
                )
              }}
            </button>
          </div>
        </div>
        <TemplateField
          v-model="step.body"
          :variables="variables"
          :placeholder="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.BODY_PLACEHOLDER')"
          multiline
        />
      </div>
    </template>

    <template v-else>
      <TemplateField
        v-model="step.left"
        :variables="variables"
        :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.LEFT')"
        :placeholder="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.LEFT_PLACEHOLDER')"
      />
      <ComboBox
        v-model="step.compare"
        :options="compareOptions"
        class="[&>div>button]:bg-n-alpha-black2"
      />
      <TemplateField
        v-if="hasExpectedValue"
        v-model="step.right"
        :variables="variables"
        :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.RIGHT')"
        :placeholder="rightPlaceholder"
      />
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

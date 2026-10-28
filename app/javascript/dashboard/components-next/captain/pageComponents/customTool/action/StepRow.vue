<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import TemplateText from './TemplateText.vue';

// One line of the step list. Opens the step panel on click.
const props = defineProps({
  step: { type: Object, required: true },
  index: { type: Number, required: true },
  // This step's entry from the last test run, if any.
  result: { type: Object, default: null },
  hasErrors: { type: Boolean, default: false },
});

const emit = defineEmits(['open']);
const { t } = useI18n();

const isRequest = computed(() => props.step.type === 'request');
const url = computed(() => (props.step.url || '').replace(/^https?:\/\//, ''));

const status = computed(() => {
  if (props.hasErrors) return 'error';
  if (!props.result) return null;
  return props.result.ok ? 'passed' : 'failed';
});
const STATUS_CLASSES = {
  passed: 'i-lucide-circle-check text-n-teal-10',
  failed: 'i-lucide-circle-x text-n-ruby-10',
  error: 'i-lucide-circle-alert text-n-ruby-10',
};
</script>

<template>
  <li class="list-none">
    <button
      type="button"
      class="flex items-center w-full gap-3 px-3 py-2.5 text-start rounded-lg hover:bg-n-alpha-1 focus-visible:outline focus-visible:outline-1 focus-visible:outline-n-brand"
      data-test="step-row"
      @click="emit('open')"
    >
      <span
        class="flex items-center justify-center text-xs rounded-full size-5 shrink-0 bg-n-alpha-2 text-n-slate-11"
      >
        {{ index + 1 }}
      </span>
      <template v-if="isRequest">
        <span
          class="w-14 font-mono text-xs font-medium shrink-0 text-n-blue-11"
        >
          {{ step.method }}
        </span>
        <TemplateText
          v-if="url"
          :text="url"
          class="flex-1 min-w-0 font-mono text-sm text-n-slate-12"
        />
        <span v-else class="flex-1 text-sm text-n-slate-10">
          {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.NO_URL') }}
        </span>
      </template>
      <template v-else>
        <span class="w-14 text-xs font-medium shrink-0 text-n-amber-11">
          {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.STEPS.VERIFY') }}
        </span>
        <span
          class="flex items-center flex-1 min-w-0 gap-1 text-sm text-n-slate-12"
        >
          <TemplateText :text="step.left" class="min-w-0" />
          <span class="i-lucide-equal size-3.5 text-n-slate-10 shrink-0" />
          <TemplateText :text="step.right" class="min-w-0" />
        </span>
      </template>
      <span
        v-if="status"
        class="size-4 shrink-0"
        :class="STATUS_CLASSES[status]"
        :data-test="`step-${status}`"
      />
      <span class="i-lucide-chevron-right size-4 shrink-0 text-n-slate-10" />
    </button>
  </li>
</template>

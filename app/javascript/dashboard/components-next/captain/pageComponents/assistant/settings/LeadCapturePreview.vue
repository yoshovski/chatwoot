<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import FlowSteps from './FlowSteps.vue';

const props = defineProps({
  enabled: { type: Boolean, default: false },
  fields: { type: Array, default: () => [] },
  types: { type: Array, default: () => [] },
  maxQuestions: { type: Number, default: 2 },
});
const { t } = useI18n();
const label = (key, params = {}) =>
  t(`CAPTAIN.ASSISTANTS.SETTINGS.LEADS.PREVIEW.${key}`, params);
const steps = computed(() => [
  {
    icon: 'i-lucide-message-circle',
    title: label('ANSWER'),
    detail: label('ANSWER_DETAIL'),
    tone: 'blue',
  },
  {
    icon: 'i-lucide-list-filter',
    title: label('QUALIFY'),
    detail: props.maxQuestions
      ? label('QUALIFY_DETAIL', { count: props.maxQuestions })
      : label('NO_QUESTIONS'),
    tone: 'slate',
  },
  {
    icon: 'i-lucide-contact-round',
    title: label('ASK'),
    detail: label('ASK_DETAIL'),
    tone: 'slate',
  },
  {
    icon: 'i-lucide-check',
    title: label('SAVE'),
    detail: label('SAVE_DETAIL'),
    tone: 'teal',
  },
]);
</script>

<template>
  <div class="flex flex-col gap-5">
    <FlowSteps :title="label('FLOW')" :steps="steps" />
    <section
      class="flex flex-col gap-3 rounded-2xl bg-n-solid-1 p-4 outline outline-1 outline-n-weak"
    >
      <div class="flex items-center justify-between gap-2">
        <span class="text-sm font-semibold text-n-slate-12">{{
          label('RECORD')
        }}</span>
        <span
          class="rounded-md bg-n-slate-3 px-2 py-1 text-xs text-n-slate-11"
          >{{ label('EXAMPLE') }}</span
        >
      </div>
      <p v-if="!enabled" class="m-0 text-xs text-n-slate-11">
        {{ label('OFF') }}
      </p>
      <dl class="m-0 flex flex-col gap-3 text-sm">
        <div>
          <dt class="text-xs text-n-slate-11">{{ label('NAME_EMAIL') }}</dt>
          <dd class="m-0 mt-0.5 break-words text-n-slate-12">
            {{ label('CONTACT_EXAMPLE') }}
          </dd>
        </div>
        <div>
          <dt class="text-xs text-n-slate-11">{{ label('TYPE') }}</dt>
          <dd class="m-0 mt-0.5 break-words text-n-slate-12">
            {{ types[0]?.name || label('NO_TYPE') }}
          </dd>
        </div>
        <div
          v-for="field in fields.filter(item => item.label)"
          :key="field.key"
        >
          <dt class="text-xs text-n-slate-11">{{ field.label }}</dt>
          <dd class="m-0 mt-0.5 text-n-slate-12">
            {{ label('CUSTOMER_VALUE') }}
          </dd>
        </div>
        <div>
          <dt class="text-xs text-n-slate-11">{{ label('SUMMARY') }}</dt>
          <dd class="m-0 mt-0.5 text-n-slate-12">
            {{ label('SUMMARY_EXAMPLE') }}
          </dd>
        </div>
      </dl>
      <p class="m-0 border-t border-n-weak pt-3 text-xs text-n-slate-11">
        {{ label('RECORD_HELP') }}
      </p>
    </section>
    <p class="m-0 px-1 text-xs leading-relaxed text-n-slate-11">
      {{ label('BOUNDARY') }}
    </p>
  </div>
</template>

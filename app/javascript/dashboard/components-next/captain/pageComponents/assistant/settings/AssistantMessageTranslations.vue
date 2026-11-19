<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Select from 'dashboard/components-next/select/Select.vue';
import SettingsSwitchRow from './SettingsSwitchRow.vue';

const props = defineProps({
  config: { type: Object, required: true },
  generated: { type: Object, default: () => ({}) },
  pendingCount: { type: Number, default: 0 },
  languages: { type: Array, required: true },
});
const emit = defineEmits(['change']);
const { t } = useI18n();
const copy = 'CAPTAIN.AGENT_UX.STYLE.LANGUAGES.MESSAGES';
const fields = [
  'handoff_message',
  'offline_handoff_message',
  'no_handoff_message',
  'handoff_form_message',
  'lead_form_message',
  'lead_form_submit',
  'resolution_message',
];
const selected = ref('');
const locale = computed(() =>
  props.languages.some(option => option.value === selected.value)
    ? selected.value
    : props.languages[0]?.value
);
const auto = computed({
  get: () => props.config.auto_translate_messages === true,
  set: value => emit('change', { auto_translate_messages: value }),
});
const edits = computed(() => props.config.localized_messages || {});
const customText = field => edits.value[field]?.[locale.value] || '';
const generatedText = field =>
  (auto.value && props.generated?.[field]?.[locale.value]) || '';
const update = (field, value) => {
  const variants = { ...edits.value[field] };
  if (value.trim()) variants[locale.value] = value;
  else delete variants[locale.value];
  emit('change', { localized_messages: { ...edits.value, [field]: variants } });
};
</script>

<template>
  <section class="flex flex-col gap-4 border-t border-n-weak pt-4">
    <h3 class="m-0 text-base font-semibold text-n-slate-12">
      {{ t(`${copy}.TITLE`) }}
    </h3>
    <SettingsSwitchRow
      v-model="auto"
      :title="t(`${copy}.AUTO`)"
      :description="t(`${copy}.AUTO_DESCRIPTION`)"
    />
    <p
      v-if="auto && pendingCount"
      class="m-0 text-sm text-n-slate-11"
      role="status"
    >
      {{ t(`${copy}.PENDING`) }}
    </p>
    <Select
      :model-value="locale"
      :options="languages"
      :aria-label="t(`${copy}.LANGUAGE`)"
      @update:model-value="selected = $event"
    />
    <label
      v-for="field in fields"
      :key="field"
      class="flex flex-col gap-1 text-sm text-n-slate-12"
    >
      <span class="font-medium">{{ t(`${copy}.${field.toUpperCase()}`) }}</span>
      <span v-if="config[field]" class="text-n-slate-11">
        {{ t(`${copy}.SOURCE`, { text: config[field] }) }}
      </span>
      <textarea
        :value="customText(field)"
        :placeholder="t(`${copy}.PLACEHOLDER`)"
        class="!mb-0 min-h-16 rounded-lg border border-n-weak bg-n-surface-1 p-2"
        maxlength="2000"
        rows="2"
        @input="update(field, $event.target.value)"
      />
      <span
        v-if="generatedText(field) && !customText(field)"
        class="text-xs text-n-slate-11"
      >
        {{ t(`${copy}.GENERATED`) }}
      </span>
      <span
        v-if="generatedText(field) && !customText(field)"
        class="whitespace-pre-wrap text-n-slate-11"
      >
        {{ generatedText(field) }}
      </span>
    </label>
  </section>
</template>

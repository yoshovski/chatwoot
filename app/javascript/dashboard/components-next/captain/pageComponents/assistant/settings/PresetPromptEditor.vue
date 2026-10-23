<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

// A compact preset switch plus a custom option. The instruction the agent gets stays one click away, and
// customizing a preset saves it as custom.
const props = defineProps({
  name: { type: String, required: true },
  title: { type: String, required: true },
  options: { type: Array, required: true },
  selected: { type: String, required: true },
  presetTexts: { type: Object, default: () => ({}) },
  customText: { type: String, default: '' },
  field: { type: String, required: true },
  promptField: { type: String, required: true },
});

const emit = defineEmits(['update']);

const { t } = useI18n();

const CUSTOM = 'custom';
const MAX_LENGTH = 1000;

const isCustom = computed(() => props.selected === CUSTOM);
const shownText = computed(() =>
  isCustom.value ? props.customText : props.presetTexts[props.selected] || ''
);

const editing = ref(false);
const showInstruction = ref(false);
const draft = ref('');

const startEditing = () => {
  draft.value = shownText.value;
  editing.value = true;
};

watch(
  () => [props.selected, props.customText],
  () => {
    editing.value = false;
  }
);

const canSave = computed(
  () => draft.value.trim() && draft.value.trim() !== props.customText
);

const save = () => {
  emit('update', {
    [props.field]: CUSTOM,
    [props.promptField]: draft.value.trim(),
  });
  editing.value = false;
};

const customOption = computed(() => ({
  id: CUSTOM,
  icon: 'i-lucide-pencil-line',
  label: t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CUSTOM_PROMPT.LABEL'),
  description: t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CUSTOM_PROMPT.DESC'),
}));

const allOptions = computed(() => [...props.options, customOption.value]);
const isActive = id =>
  id === CUSTOM
    ? isCustom.value || editing.value
    : !editing.value && props.selected === id;
const activeDescription = computed(
  () => allOptions.value.find(option => isActive(option.id))?.description || ''
);

const select = id => {
  if (id === CUSTOM) {
    if (!isCustom.value) startEditing();
    return;
  }
  emit('update', { [props.field]: id });
};
</script>

<template>
  <section class="flex flex-col gap-2">
    <div class="flex items-center justify-between gap-3">
      <h3 class="text-base font-semibold text-n-slate-12">{{ title }}</h3>
      <Button
        v-if="shownText && !editing"
        :label="
          showInstruction
            ? t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CUSTOM_PROMPT.HIDE')
            : t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CUSTOM_PROMPT.VIEW')
        "
        :icon="showInstruction ? 'i-lucide-eye-off' : 'i-lucide-eye'"
        size="xs"
        variant="ghost"
        color="slate"
        :aria-expanded="showInstruction"
        @click="showInstruction = !showInstruction"
      />
    </div>
    <div
      class="flex flex-wrap gap-1 p-1 rounded-lg bg-n-alpha-1"
      role="radiogroup"
      :aria-label="title"
    >
      <button
        v-for="option in allOptions"
        :key="option.id"
        type="button"
        role="radio"
        :name="name"
        :aria-checked="isActive(option.id)"
        class="flex items-center justify-center flex-1 gap-1.5 px-3 py-1.5 text-sm font-medium transition-colors rounded-md min-w-24 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
        :class="
          isActive(option.id)
            ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
            : 'text-n-slate-11 hover:text-n-slate-12'
        "
        @click="select(option.id)"
      >
        <span v-if="option.icon" :class="option.icon" class="size-4" />
        {{ option.label }}
      </button>
    </div>
    <p v-if="activeDescription" class="m-0 text-sm text-n-slate-11">
      {{ activeDescription }}
    </p>
    <div
      v-if="editing"
      class="flex flex-col gap-2 p-3 rounded-xl bg-n-alpha-1 outline outline-1 outline-n-weak"
    >
      <TextArea
        v-model="draft"
        :label="t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CUSTOM_PROMPT.EDITOR')"
        :max-length="MAX_LENGTH"
        show-character-count
        auto-height
        min-height="5rem"
        autofocus
      />
      <p class="m-0 text-xs text-n-slate-11">
        {{ t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CUSTOM_PROMPT.HINT') }}
      </p>
      <div class="flex justify-end gap-2">
        <Button
          :label="
            t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CUSTOM_PROMPT.CANCEL')
          "
          size="sm"
          variant="faded"
          color="slate"
          @click="editing = false"
        />
        <Button
          v-if="canSave"
          :label="t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CUSTOM_PROMPT.SAVE')"
          size="sm"
          @click="save"
        />
      </div>
    </div>
    <div
      v-else-if="showInstruction && shownText"
      class="flex flex-col gap-2 p-3 text-sm rounded-xl bg-n-alpha-1 text-n-slate-11"
    >
      <p class="m-0 leading-relaxed whitespace-pre-line">
        {{ shownText }}
      </p>
      <Button
        :label="t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CUSTOM_PROMPT.EDIT')"
        icon="i-lucide-pencil-line"
        size="xs"
        variant="faded"
        color="slate"
        class="self-start"
        @click="startEditing"
      />
    </div>
  </section>
</template>

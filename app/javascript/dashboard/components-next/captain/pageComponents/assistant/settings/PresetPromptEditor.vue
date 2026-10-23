<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import ChoiceCard from './ChoiceCard.vue';

// Presets plus a custom option: each preset shows the instruction the agent gets, and editing one saves it as custom.
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

const select = id => {
  if (id === CUSTOM) {
    if (!isCustom.value) startEditing();
    return;
  }
  emit('update', { [props.field]: id });
};
</script>

<template>
  <section class="flex flex-col gap-3">
    <h3 class="text-base font-semibold text-n-slate-12">{{ title }}</h3>
    <div class="flex flex-col gap-2" role="radiogroup" :aria-label="title">
      <ChoiceCard
        v-for="option in [...options, customOption]"
        :key="option.id"
        :name="name"
        :value="option.id"
        :icon="option.icon"
        :label="option.label"
        :description="option.description"
        :is-active="
          option.id === CUSTOM ? isCustom || editing : selected === option.id
        "
        @select="select(option.id)"
      />
    </div>
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
    <details v-else-if="shownText" class="text-sm text-n-slate-11">
      <summary
        class="font-medium cursor-pointer text-n-slate-12 marker:text-n-slate-10"
      >
        {{ t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CUSTOM_PROMPT.SHOW') }}
      </summary>
      <p class="mt-2 mb-1 leading-relaxed whitespace-pre-line">
        {{ shownText }}
      </p>
      <Button
        :label="t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CUSTOM_PROMPT.EDIT')"
        size="xs"
        variant="link"
        @click="startEditing"
      />
    </details>
  </section>
</template>

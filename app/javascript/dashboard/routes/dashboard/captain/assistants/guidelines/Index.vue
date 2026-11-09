<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useShopifyIntegration } from 'dashboard/composables/useShopifyIntegration';
import { useAssistantSettings } from '../settings/useAssistantSettings';
import Button from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

import SettingsPageLayout from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsPageLayout.vue';
import SettingsSplit from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsSplit.vue';
import SettingsCard from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsCard.vue';
import SettingsSwitchRow from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsSwitchRow.vue';
import SettingsSaveBar from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsSaveBar.vue';
import SettingsPanel from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsPanel.vue';
import SummaryRow from 'dashboard/components-next/captain/pageComponents/assistant/settings/SummaryRow.vue';
import SegmentedChoice from 'dashboard/components-next/captain/pageComponents/assistant/settings/SegmentedChoice.vue';
import InstructionsPreview from 'dashboard/components-next/captain/pageComponents/assistant/settings/InstructionsPreview.vue';

const { t } = useI18n();
const { isConnected: isShopifyConnected } = useShopifyIntegration();
const { assistantId, assistant, updateAssistant } = useAssistantSettings();

const B = 'CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR';
const U = 'CAPTAIN.AGENT_UX.STYLE';
const CUSTOM = 'custom';
// Mirrors Captain::Assistant::BUSINESS_TYPES; an empty value lets the server detect it.
const BUSINESS_TYPES = [
  'commerce',
  'software',
  'subscription',
  'services',
  'general',
];
const MIN_BUTTONS = 1;
const MAX_BUTTONS = 5;

// Changes collect in a draft; the save bar commits them like every other settings page.
const draft = ref({});
const saved = computed(() => assistant.value?.config || {});
const config = computed(() => ({ ...saved.value, ...draft.value }));
const set = patch => {
  draft.value = { ...draft.value, ...patch };
};
const isDirty = computed(() =>
  Object.entries(draft.value).some(
    ([key, value]) => JSON.stringify(saved.value[key]) !== JSON.stringify(value)
  )
);
const isSaving = ref(false);
const save = async () => {
  isSaving.value = true;
  const ok = await updateAssistant({
    config: { ...saved.value, ...draft.value },
  });
  isSaving.value = false;
  if (ok) draft.value = {};
};
const discard = () => {
  draft.value = {};
};
watch(assistantId, discard);

const name = computed(() => assistant.value?.name || '');
const previewAssistant = computed(() => ({
  ...assistant.value,
  config: config.value,
}));
const presets = computed(() => assistant.value?.prompt_presets || {});

// Tone and length: presets on the page, exact wording in a panel.
const presetOptions = (ids, group) => [
  ...ids.map(([id, icon]) => ({
    id,
    icon,
    label: t(`${B}.${group}.${id.toUpperCase()}.LABEL`),
  })),
  {
    id: CUSTOM,
    icon: 'i-lucide-pencil-line',
    label: t(`${B}.CUSTOM_PROMPT.LABEL`),
  },
];
const toneOptions = computed(() =>
  presetOptions(
    [
      ['friendly', 'i-lucide-smile'],
      ['professional', 'i-lucide-briefcase'],
      ['short', 'i-lucide-zap'],
    ],
    'TONE'
  )
);
const lengthOptions = computed(() =>
  presetOptions(
    [
      ['short', 'i-lucide-minus'],
      ['balanced', 'i-lucide-align-left'],
      ['detailed', 'i-lucide-list-ordered'],
    ],
    'ANSWER_LENGTH'
  )
);

const exactOpen = ref(false);
const choice = (field, promptField, presetGroup, fallback) =>
  computed({
    get: () => config.value[field] || fallback,
    set: value => {
      if (value !== CUSTOM) {
        set({ [field]: value });
        return;
      }
      const current = config.value[field] || fallback;
      set({
        [field]: CUSTOM,
        [promptField]:
          config.value[promptField] ||
          presets.value[presetGroup]?.[current] ||
          '',
      });
      exactOpen.value = true;
    },
  });
const tone = choice('tone', 'tone_prompt', 'tone', 'friendly');
const answerLength = choice(
  'answer_length',
  'answer_length_prompt',
  'answer_length',
  'balanced'
);
const choiceHint = (value, group) =>
  value === CUSTOM
    ? t(`${U}.CUSTOM_HINT`, { name: name.value })
    : t(`${B}.${group}.${value.toUpperCase()}.DESC`);

const exactBlocks = computed(() => [
  {
    key: 'tone',
    title: t(`${U}.TONE`),
    model: tone,
    promptField: 'tone_prompt',
    presetText: presets.value.tone?.[tone.value] || '',
  },
  {
    key: 'answer_length',
    title: t(`${U}.LENGTH`),
    model: answerLength,
    promptField: 'answer_length_prompt',
    presetText: presets.value.answer_length?.[answerLength.value] || '',
  },
]);

// Business type: a summary with the full explanation in its panel, never behind a toggle.
const businessOpen = ref(false);
const detectedType = computed(
  () =>
    assistant.value?.detected_business_type ||
    (isShopifyConnected.value ? 'commerce' : 'general')
);
const isDetected = computed(() => !config.value.business_type);
const businessType = computed(
  () => config.value.business_type || detectedType.value
);
const businessLabel = type =>
  t(`${B}.BUSINESS_TYPE.OPTIONS.${type.toUpperCase()}`);
const businessSummary = computed(
  () =>
    `${businessLabel(businessType.value)} · ${t(
      isDetected.value ? `${U}.DETECTED_SUFFIX` : `${U}.CHOSEN_SUFFIX`
    )}`
);

// Reply extras: five small toggles become one line on the page.
const extrasOpen = ref(false);
const toggle = (key, defaultOn = false) =>
  computed({
    get: () =>
      defaultOn ? config.value[key] !== false : Boolean(config.value[key]),
    set: value => set({ [key]: value }),
  });
const buttons = toggle('suggested_replies');
const productCards = toggle('product_cards');
const followUp = toggle('follow_up_questions', true);
const showFollowUp = computed(() => businessType.value !== 'commerce');
const maxButtons = computed(() => config.value.max_suggested_replies ?? 3);
const changeMaxButtons = delta =>
  set({
    max_suggested_replies: Math.min(
      MAX_BUTTONS,
      Math.max(MIN_BUTTONS, maxButtons.value + delta)
    ),
  });
const linksMode = computed({
  get: () => config.value.helpful_links_mode || 'automatic',
  set: value => set({ helpful_links_mode: value }),
});
const linksOptions = computed(() => [
  { value: 'automatic', label: t(`${B}.CARDS.HELPFUL_LINKS.AUTOMATIC`) },
  { value: 'on_request', label: t(`${B}.CARDS.HELPFUL_LINKS.ON_REQUEST`) },
]);
const extrasSummary = computed(() =>
  [
    buttons.value && t(`${U}.BUTTONS_SUMMARY`, { count: maxButtons.value }),
    `${t(`${U}.LINKS_LABEL`)}: ${linksOptions.value
      .find(o => o.value === linksMode.value)
      .label.toLowerCase()}`,
    showFollowUp.value && followUp.value && t(`${U}.FOLLOW_UP_LABEL`),
    isShopifyConnected.value && productCards.value && t(`${U}.PRODUCTS_LABEL`),
  ]
    .filter(Boolean)
    .join(' · ')
);
</script>

<template>
  <SettingsPageLayout :heading="t('CAPTAIN.AGENT_UX.SECTIONS.BEHAVIOR')">
    <SettingsSplit>
      <section class="flex flex-col gap-5">
        <h3 class="m-0 text-base font-semibold text-n-slate-12">
          {{ t(`${U}.VOICE_TITLE`, { name }) }}
        </h3>
        <div class="flex flex-col gap-2">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t(`${U}.TONE`) }}
          </span>
          <SegmentedChoice
            v-model="tone"
            :label="t(`${U}.TONE`)"
            :options="toneOptions"
          />
          <p class="m-0 text-sm text-n-slate-11">
            {{ choiceHint(tone, 'TONE') }}
          </p>
        </div>
        <div class="flex flex-col gap-2">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t(`${U}.LENGTH`) }}
          </span>
          <SegmentedChoice
            v-model="answerLength"
            :label="t(`${U}.LENGTH`)"
            :options="lengthOptions"
          />
          <p class="m-0 text-sm text-n-slate-11">
            {{ choiceHint(answerLength, 'ANSWER_LENGTH') }}
          </p>
        </div>
      </section>

      <SettingsCard>
        <SummaryRow
          icon="i-lucide-store"
          :title="t(`${U}.BUSINESS_TITLE`)"
          :summary="businessSummary"
          :action-label="t('CAPTAIN.AGENT_UX.CHANGE')"
          @edit="businessOpen = true"
        />
        <SummaryRow
          icon="i-lucide-mouse-pointer-click"
          :title="t(`${U}.EXTRAS_TITLE`)"
          :summary="extrasSummary"
          @edit="extrasOpen = true"
        />
        <SummaryRow
          icon="i-lucide-file-text"
          :title="t(`${U}.EXACT_TITLE`)"
          :summary="t(`${U}.EXACT_SUMMARY`, { name })"
          muted
          @edit="exactOpen = true"
        />
      </SettingsCard>

      <SettingsSaveBar
        :is-dirty="isDirty"
        :is-saving="isSaving"
        @save="save"
        @discard="discard"
      />

      <template #preview>
        <InstructionsPreview
          :assistant="previewAssistant"
          :show-product-cards="isShopifyConnected"
        />
        <p v-if="isDirty" class="m-0 text-xs text-center text-n-amber-11">
          {{ t('CAPTAIN.AGENT_UX.UNSAVED_PREVIEW') }}
        </p>
      </template>
    </SettingsSplit>

    <SettingsPanel
      v-model:open="businessOpen"
      :title="t(`${U}.BUSINESS_TITLE`)"
      :description="t(`${U}.BUSINESS_PANEL_DESC`, { name })"
    >
      <div
        class="flex flex-col gap-2"
        role="radiogroup"
        :aria-label="t(`${U}.BUSINESS_TITLE`)"
      >
        <button
          v-for="type in BUSINESS_TYPES"
          :key="type"
          type="button"
          role="radio"
          :aria-checked="type === businessType"
          class="flex flex-col items-start gap-0.5 px-4 py-3 text-start rounded-xl outline transition-colors"
          :class="
            type === businessType
              ? 'outline-2 outline-n-brand bg-n-alpha-1'
              : 'outline-1 outline-n-weak hover:outline-n-strong'
          "
          @click="set({ business_type: type })"
        >
          <span class="text-sm font-medium text-n-slate-12">
            {{ businessLabel(type) }}
            <span
              v-if="type === detectedType"
              class="ms-1 text-xs font-normal text-n-slate-10"
            >
              {{ t(`${B}.BUSINESS_TYPE.DETECTED`) }}
            </span>
          </span>
          <span class="text-sm text-n-slate-11">
            {{ t(`${B}.BUSINESS_TYPE.HINTS.${type.toUpperCase()}`) }}
          </span>
        </button>
      </div>
      <Button
        v-if="!isDetected"
        :label="t(`${B}.BUSINESS_TYPE.USE_DETECTED`)"
        icon="i-lucide-wand-sparkles"
        size="sm"
        variant="link"
        class="self-start"
        @click="set({ business_type: '' })"
      />
      <div class="flex flex-col gap-1 p-4 rounded-xl bg-n-alpha-1">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t(`${U}.BUSINESS_WHAT_CHANGES`) }}
        </span>
        <p class="m-0 text-sm leading-relaxed text-n-slate-11">
          {{ t(`${B}.BUSINESS_TYPE.DETAILS.${businessType.toUpperCase()}`) }}
        </p>
      </div>
    </SettingsPanel>

    <SettingsPanel
      v-model:open="extrasOpen"
      :title="t(`${U}.EXTRAS_TITLE`)"
      :description="t(`${U}.EXTRAS_PANEL_DESC`, { name })"
      width="5xl"
    >
      <div class="grid items-start gap-8 lg:grid-cols-[minmax(0,1fr)_20rem]">
        <div class="flex flex-col divide-y divide-n-weak">
          <SettingsSwitchRow
            v-model="buttons"
            :title="t(`${U}.BUTTONS_LABEL`)"
            :description="t(`${B}.CARDS.QUICK_REPLIES.DESC`)"
          >
            <div v-if="buttons" class="flex items-center gap-2 pt-2">
              <Button
                icon="i-lucide-minus"
                size="xs"
                color="slate"
                variant="faded"
                :aria-label="t(`${B}.CARDS.QUICK_REPLIES.FEWER`)"
                :disabled="maxButtons <= MIN_BUTTONS"
                @click="changeMaxButtons(-1)"
              />
              <span class="text-sm text-n-slate-12" aria-live="polite">
                {{ t(`${U}.BUTTONS_SUMMARY`, { count: maxButtons }) }}
              </span>
              <Button
                icon="i-lucide-plus"
                size="xs"
                color="slate"
                variant="faded"
                :aria-label="t(`${B}.CARDS.QUICK_REPLIES.MORE`)"
                :disabled="maxButtons >= MAX_BUTTONS"
                @click="changeMaxButtons(1)"
              />
            </div>
          </SettingsSwitchRow>
          <div class="flex items-start justify-between gap-4 py-3.5">
            <div class="flex flex-col gap-0.5 min-w-0">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t(`${U}.LINKS_LABEL`) }}
              </span>
              <span class="text-sm text-n-slate-11">
                {{ t(`${B}.CARDS.HELPFUL_LINKS.NOTE`) }}
              </span>
            </div>
            <Select
              v-model="linksMode"
              :options="linksOptions"
              :aria-label="t(`${U}.LINKS_LABEL`)"
              class="shrink-0"
            />
          </div>
          <SettingsSwitchRow
            v-if="showFollowUp"
            v-model="followUp"
            :title="t(`${U}.FOLLOW_UP_LABEL`)"
            :description="t(`${B}.CARDS.FOLLOW_UP.NOTE`)"
          />
          <SettingsSwitchRow
            v-if="isShopifyConnected"
            v-model="productCards"
            :title="t(`${U}.PRODUCTS_LABEL`)"
            :description="t(`${B}.CARDS.PRODUCT_CARDS.NOTE`)"
          />
        </div>
        <div class="flex flex-col gap-2 lg:sticky lg:top-0">
          <InstructionsPreview
            :assistant="previewAssistant"
            :show-product-cards="isShopifyConnected"
          />
        </div>
      </div>
    </SettingsPanel>

    <SettingsPanel
      v-model:open="exactOpen"
      :title="t(`${U}.EXACT_PANEL_TITLE`)"
      :description="t(`${U}.EXACT_PANEL_DESC`)"
      width="5xl"
    >
      <div class="grid items-start gap-8 lg:grid-cols-[minmax(0,1fr)_20rem]">
        <div class="flex flex-col gap-5">
          <section
            v-for="block in exactBlocks"
            :key="block.key"
            class="flex flex-col gap-2"
          >
            <span class="text-sm font-medium text-n-slate-12">
              {{ block.title }}
            </span>
            <SegmentedChoice
              v-model="block.model.value"
              :label="block.title"
              :options="block.key === 'tone' ? toneOptions : lengthOptions"
            />
            <TextArea
              v-if="block.model.value === CUSTOM"
              :model-value="config[block.promptField] || ''"
              :label="t(`${B}.CUSTOM_PROMPT.EDITOR`)"
              :max-length="1000"
              show-character-count
              auto-height
              min-height="6rem"
              @update:model-value="value => set({ [block.promptField]: value })"
            />
            <p
              v-else
              class="p-3 m-0 text-sm leading-relaxed whitespace-pre-line rounded-xl bg-n-alpha-1 text-n-slate-11"
            >
              {{ block.presetText }}
            </p>
          </section>
          <p class="m-0 text-xs text-n-slate-11">
            {{ t(`${B}.CUSTOM_PROMPT.HINT`) }}
          </p>
        </div>
        <div class="flex flex-col gap-2 lg:sticky lg:top-0">
          <InstructionsPreview
            :assistant="previewAssistant"
            :show-product-cards="isShopifyConnected"
          />
        </div>
      </div>
    </SettingsPanel>
  </SettingsPageLayout>
</template>

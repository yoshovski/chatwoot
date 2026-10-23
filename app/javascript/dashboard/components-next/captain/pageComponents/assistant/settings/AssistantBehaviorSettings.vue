<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import ChoiceCard from './ChoiceCard.vue';
import SettingsCard from './SettingsCard.vue';
import SettingsSwitchRow from './SettingsSwitchRow.vue';

const props = defineProps({
  showProductCards: { type: Boolean, default: false },
  assistant: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['update']);

const { t } = useI18n();

const TONES = [
  { id: 'friendly', icon: 'i-lucide-smile' },
  { id: 'professional', icon: 'i-lucide-briefcase' },
  { id: 'short', icon: 'i-lucide-zap' },
];
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
const DEFAULT_BUTTONS = 3;

const config = computed(() => props.assistant.config || {});
const maxButtons = computed(
  () => config.value.max_suggested_replies ?? DEFAULT_BUTTONS
);

const toneOptions = computed(() =>
  TONES.map(({ id, icon }) => ({
    id,
    icon,
    label: t(
      `CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.TONE.${id.toUpperCase()}.LABEL`
    ),
    description: t(
      `CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.TONE.${id.toUpperCase()}.DESC`
    ),
  }))
);

const businessTypeLabel = type =>
  t(
    `CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.BUSINESS_TYPE.OPTIONS.${type.toUpperCase()}`
  );
const detectedBusinessType = computed(
  () =>
    props.assistant.detected_business_type ||
    (props.showProductCards ? 'commerce' : 'general')
);
// An empty business_type means detected; the detected chip shows as selected.
const shownBusinessType = computed(
  () => config.value.business_type || detectedBusinessType.value
);
const businessTypeOptions = computed(() =>
  BUSINESS_TYPES.map(type => ({
    value: type,
    label: businessTypeLabel(type),
    selected: type === shownBusinessType.value,
  }))
);

const update = patch => emit('update', patch);

const isBusinessTypeDetected = computed(() => !config.value.business_type);
const businessTypeKey = computed(() => shownBusinessType.value.toUpperCase());

const toggle = key =>
  computed({
    get: () => Boolean(config.value[key]),
    set: value => update({ [key]: value }),
  });

const suggestedReplies = toggle('suggested_replies');
const productCards = toggle('product_cards');
const citations = toggle('feature_citation');

const changeMaxButtons = delta => {
  const next = Math.min(
    MAX_BUTTONS,
    Math.max(MIN_BUTTONS, maxButtons.value + delta)
  );
  if (next !== maxButtons.value) update({ max_suggested_replies: next });
};
</script>

<template>
  <div class="flex flex-col gap-6">
    <section class="flex flex-col gap-3">
      <h3 class="text-base font-semibold text-n-slate-12">
        {{ t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.BUSINESS_TYPE.TITLE') }}
      </h3>
      <div
        class="flex flex-wrap gap-2"
        role="radiogroup"
        :aria-label="
          t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.BUSINESS_TYPE.TITLE')
        "
      >
        <button
          v-for="option in businessTypeOptions"
          :key="option.value"
          type="button"
          role="radio"
          :aria-checked="option.selected"
          class="flex items-center gap-1.5 h-9 px-3.5 text-sm font-medium rounded-lg outline transition-colors"
          :class="
            option.selected
              ? 'outline-2 outline-n-blue-9 bg-n-blue-1 text-n-blue-11'
              : 'outline-1 outline-n-weak bg-n-solid-1 text-n-slate-12 hover:outline-n-strong'
          "
          @click="update({ business_type: option.value })"
        >
          {{ option.label }}
          <span
            v-if="option.selected && isBusinessTypeDetected"
            class="text-xs font-normal text-n-slate-11"
          >
            {{
              t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.BUSINESS_TYPE.DETECTED')
            }}
          </span>
        </button>
      </div>
      <p class="m-0 text-sm text-n-slate-11">
        {{
          t(
            `CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.BUSINESS_TYPE.HINTS.${businessTypeKey}`
          )
        }}
        <Button
          v-if="!isBusinessTypeDetected"
          :label="
            t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.BUSINESS_TYPE.USE_DETECTED')
          "
          size="xs"
          variant="link"
          class="ms-1"
          @click="update({ business_type: '' })"
        />
      </p>
      <details class="text-sm group text-n-slate-11">
        <summary
          class="font-medium cursor-pointer text-n-slate-12 marker:text-n-slate-10"
        >
          {{
            t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.BUSINESS_TYPE.WHAT_CHANGES')
          }}
        </summary>
        <p class="mt-2 mb-0 leading-relaxed">
          {{
            t(
              `CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.BUSINESS_TYPE.DETAILS.${businessTypeKey}`
            )
          }}
        </p>
      </details>
    </section>

    <section class="flex flex-col gap-3">
      <h3 class="text-base font-semibold text-n-slate-12">
        {{ t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.TONE.TITLE') }}
      </h3>
      <div
        class="flex flex-col gap-2"
        role="radiogroup"
        :aria-label="t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.TONE.TITLE')"
      >
        <ChoiceCard
          v-for="option in toneOptions"
          :key="option.id"
          name="assistant-tone"
          :value="option.id"
          :icon="option.icon"
          :label="option.label"
          :description="option.description"
          :is-active="config.tone === option.id"
          @select="update({ tone: option.id })"
        />
      </div>
    </section>

    <section class="flex flex-col gap-3">
      <h3 class="text-base font-semibold text-n-slate-12">
        {{ t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.TITLE') }}
      </h3>
      <SettingsCard>
        <SettingsSwitchRow
          v-model="suggestedReplies"
          :title="
            t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.QUICK_REPLIES.TITLE')
          "
          :description="
            t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.QUICK_REPLIES.DESC')
          "
        />
        <div
          v-if="suggestedReplies"
          class="flex items-center justify-between gap-2 py-3"
        >
          <span class="text-sm text-n-slate-11">
            {{
              t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.QUICK_REPLIES.MAX')
            }}
          </span>
          <div class="flex items-center gap-1">
            <Button
              icon="i-lucide-minus"
              size="xs"
              color="slate"
              variant="faded"
              :aria-label="
                t(
                  'CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.QUICK_REPLIES.FEWER'
                )
              "
              :disabled="maxButtons <= MIN_BUTTONS"
              @click="changeMaxButtons(-1)"
            />
            <span
              class="w-6 text-sm font-medium text-center text-n-slate-12"
              aria-live="polite"
            >
              {{ maxButtons }}
            </span>
            <Button
              icon="i-lucide-plus"
              size="xs"
              color="slate"
              variant="faded"
              :aria-label="
                t(
                  'CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.QUICK_REPLIES.MORE'
                )
              "
              :disabled="maxButtons >= MAX_BUTTONS"
              @click="changeMaxButtons(1)"
            />
          </div>
        </div>
        <SettingsSwitchRow
          v-model="citations"
          :title="t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.SOURCES.TITLE')"
          :description="
            t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.SOURCES.NOTE', {
              name: assistant.name,
            })
          "
        />
        <SettingsSwitchRow
          v-if="showProductCards"
          v-model="productCards"
          :title="
            t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.PRODUCT_CARDS.TITLE')
          "
          :description="
            t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.PRODUCT_CARDS.NOTE')
          "
        />
      </SettingsCard>
    </section>
  </div>
</template>

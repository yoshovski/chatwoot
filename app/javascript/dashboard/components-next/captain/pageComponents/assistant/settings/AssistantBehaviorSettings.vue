<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import RadioCard from 'dashboard/components-next/radioCard/RadioCard.vue';
import ReplyPreviewCard from './ReplyPreviewCard.vue';

const props = defineProps({
  assistant: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['update']);

const { t } = useI18n();

const TONES = ['friendly', 'professional', 'short'];
const MIN_BUTTONS = 1;
const MAX_BUTTONS = 5;
const DEFAULT_BUTTONS = 3;

const config = computed(() => props.assistant.config || {});
const maxButtons = computed(
  () => config.value.max_suggested_replies ?? DEFAULT_BUTTONS
);
const quickReplyButtons = computed(() =>
  ['BUTTON_1', 'BUTTON_2', 'BUTTON_3']
    .slice(0, maxButtons.value)
    .map(key =>
      t(`CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.QUICK_REPLIES.${key}`)
    )
);

const toneOptions = computed(() =>
  TONES.map(tone => ({
    id: tone,
    label: t(`CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.TONE.${tone.toUpperCase()}.LABEL`),
    description: t(
      `CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.TONE.${tone.toUpperCase()}.DESC`
    ),
  }))
);

const update = patch => emit('update', patch);

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
      <h3 class="text-sm font-semibold text-n-slate-12">
        {{ t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.TONE.TITLE') }}
      </h3>
      <div class="grid gap-3 sm:grid-cols-3">
        <RadioCard
          v-for="option in toneOptions"
          :id="`tone-${option.id}`"
          :key="option.id"
          name="assistant-tone"
          :label="option.label"
          :description="option.description"
          :is-active="config.tone === option.id"
          @select="update({ tone: option.id })"
        />
      </div>
    </section>

    <section class="flex flex-col gap-3">
      <h3 class="text-sm font-semibold text-n-slate-12">
        {{ t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.TITLE') }}
      </h3>
      <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        <ReplyPreviewCard
          v-model="suggestedReplies"
          :title="
            t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.QUICK_REPLIES.TITLE')
          "
        >
          <template #preview>
            <span>
              {{
                t(
                  'CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.QUICK_REPLIES.PREVIEW_TEXT'
                )
              }}
            </span>
            <span class="flex flex-wrap gap-1.5">
              <span
                v-for="label in quickReplyButtons"
                :key="label"
                class="px-2.5 py-0.5 text-xs rounded-full outline outline-1 outline-n-brand text-n-brand"
              >
                {{ label }}
              </span>
            </span>
          </template>
          <div class="flex items-center justify-between gap-2">
            <span class="text-xs text-n-slate-11">
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
                :disabled="!suggestedReplies || maxButtons <= MIN_BUTTONS"
                @click="changeMaxButtons(-1)"
              />
              <span
                class="w-5 text-sm font-medium text-center text-n-slate-12"
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
                :disabled="!suggestedReplies || maxButtons >= MAX_BUTTONS"
                @click="changeMaxButtons(1)"
              />
            </div>
          </div>
        </ReplyPreviewCard>

        <ReplyPreviewCard
          v-model="productCards"
          :title="
            t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.PRODUCT_CARDS.TITLE')
          "
          :note="
            t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.PRODUCT_CARDS.NOTE')
          "
        >
          <template #preview>
            <span class="flex items-center gap-2.5">
              <span class="rounded-md size-10 bg-n-slate-5 shrink-0" />
              <span class="flex flex-col text-xs">
                <span class="font-medium">
                  {{
                    t(
                      'CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.PRODUCT_CARDS.PREVIEW_NAME'
                    )
                  }}
                </span>
                <span class="text-n-slate-11">
                  {{
                    t(
                      'CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.PRODUCT_CARDS.PREVIEW_PRICE'
                    )
                  }}
                </span>
                <span class="text-n-brand">
                  {{
                    t(
                      'CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.PRODUCT_CARDS.PREVIEW_LINK'
                    )
                  }}
                </span>
              </span>
            </span>
          </template>
        </ReplyPreviewCard>

        <ReplyPreviewCard
          v-model="citations"
          :title="t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.SOURCES.TITLE')"
          :note="
            t('CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.SOURCES.NOTE', {
              name: assistant.name,
            })
          "
        >
          <template #preview>
            <span>
              {{
                t(
                  'CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.SOURCES.PREVIEW_TEXT'
                )
              }}
            </span>
            <span class="text-xs text-n-brand">
              {{
                t(
                  'CAPTAIN.ASSISTANTS.SETTINGS.BEHAVIOR.CARDS.SOURCES.PREVIEW_LINK'
                )
              }}
            </span>
          </template>
        </ReplyPreviewCard>
      </div>
    </section>
  </div>
</template>

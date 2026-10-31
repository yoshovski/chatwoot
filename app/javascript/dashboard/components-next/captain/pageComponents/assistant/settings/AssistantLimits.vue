<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import SettingsCard from './SettingsCard.vue';

// "Can't do X → offer Y": what the agent says plainly it can't do, and the next step it offers instead.
const props = defineProps({
  assistant: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();

const MAX_LIMITS = 15;
const CANNOT_MAX_LENGTH = 200;
const VALUE_MAX_LENGTH = 300;
const OFFERS_WITH_VALUE = ['link', 'text'];

const examples = computed(() => [
  t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIMITS.EXAMPLES.REFUNDS'),
  t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIMITS.EXAMPLES.PLAN_CHANGE'),
  t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIMITS.EXAMPLES.LEGAL'),
]);

const needsValue = offer => OFFERS_WITH_VALUE.includes(offer);

const toLimit = ({ cannot = '', offer = 'handoff', value = '' }) => {
  const limit = { cannot: cannot.trim(), offer };
  if (needsValue(offer)) limit.value = (value || '').trim();
  return limit;
};

const savedLimits = computed(() =>
  (props.assistant?.config?.limits || []).map(toLimit)
);

const rows = ref([]);
const showErrors = ref(false);

const reset = () => {
  rows.value = savedLimits.value.map(limit => ({ value: '', ...limit }));
  showErrors.value = false;
};

watch(savedLimits, reset, { immediate: true });

const limits = computed(() => rows.value.map(toLimit));
const isDirty = computed(
  () => JSON.stringify(limits.value) !== JSON.stringify(savedLimits.value)
);

const offerOptions = computed(() => [
  {
    value: 'handoff',
    label: t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIMITS.OFFERS.HANDOFF'),
  },
  {
    value: 'email_followup',
    label: t(
      'CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIMITS.OFFERS.EMAIL_FOLLOWUP'
    ),
  },
  {
    value: 'link',
    label: t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIMITS.OFFERS.LINK'),
  },
  {
    value: 'text',
    label: t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIMITS.OFFERS.TEXT'),
  },
]);

const isHttpUrl = value => {
  try {
    return ['http:', 'https:'].includes(new URL(value).protocol);
  } catch {
    return false;
  }
};

const limitError = ({ cannot, offer, value }) => {
  if (!cannot)
    return t(
      'CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIMITS.ERRORS.CANNOT_REQUIRED'
    );
  if (cannot.length > CANNOT_MAX_LENGTH)
    return t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIMITS.ERRORS.TOO_LONG', {
      max: CANNOT_MAX_LENGTH,
    });
  if (offer === 'link' && !isHttpUrl(value))
    return t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIMITS.ERRORS.LINK');
  if (offer === 'text' && !value)
    return t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIMITS.ERRORS.TEXT');
  if ((value || '').length > VALUE_MAX_LENGTH)
    return t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIMITS.ERRORS.TOO_LONG', {
      max: VALUE_MAX_LENGTH,
    });
  return '';
};

const errors = computed(() => limits.value.map(limitError));

const addLimit = () => {
  rows.value.push({ cannot: '', offer: 'handoff', value: '' });
};

const removeLimit = index => {
  rows.value.splice(index, 1);
};

const save = () => {
  showErrors.value = true;
  if (errors.value.some(Boolean)) return;

  emit('submit', {
    config: { ...props.assistant.config, limits: limits.value },
  });
};
</script>

<template>
  <SettingsCard
    :title="
      t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIMITS.TITLE', {
        name: assistant.name,
      })
    "
    :description="t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIMITS.DESC')"
  >
    <div class="flex flex-col gap-3 pt-2">
      <p v-if="!rows.length" class="m-0 text-sm text-n-slate-11">
        {{ t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIMITS.EMPTY') }}
      </p>
      <div
        v-for="(row, index) in rows"
        :key="index"
        class="flex flex-col gap-2 p-3 rounded-lg bg-n-alpha-1"
        data-test-id="limit-row"
      >
        <div class="flex items-center gap-2">
          <span class="text-sm font-medium shrink-0 text-n-slate-12">
            {{ t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIMITS.CANNOT') }}
          </span>
          <Input
            v-model="row.cannot"
            size="sm"
            class="flex-1 min-w-0"
            :placeholder="examples[index % examples.length]"
          />
          <Button
            type="button"
            variant="ghost"
            color="slate"
            size="xs"
            icon="i-lucide-trash-2"
            :aria-label="
              t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIMITS.REMOVE')
            "
            @click="removeLimit(index)"
          />
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <span class="text-sm shrink-0 text-n-slate-11">
            {{ t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIMITS.OFFER') }}
          </span>
          <Select
            v-model="row.offer"
            :options="offerOptions"
            :aria-label="
              t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIMITS.OFFER')
            "
          />
          <Input
            v-if="needsValue(row.offer)"
            v-model="row.value"
            size="sm"
            class="flex-1 min-w-48"
            :placeholder="
              row.offer === 'link'
                ? t(
                    'CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIMITS.LINK_PLACEHOLDER'
                  )
                : t(
                    'CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIMITS.TEXT_PLACEHOLDER'
                  )
            "
          />
        </div>
        <p v-if="showErrors && errors[index]" class="m-0 text-xs text-n-ruby-9">
          {{ errors[index] }}
        </p>
      </div>
      <div class="flex flex-wrap items-center gap-2">
        <Button
          type="button"
          :label="t('CAPTAIN.ASSISTANTS.SETTINGS.BOUNDARIES.LIMITS.ADD')"
          icon="i-lucide-plus"
          variant="faded"
          color="slate"
          size="sm"
          :disabled="rows.length >= MAX_LIMITS"
          @click="addLimit"
        />
        <template v-if="isDirty">
          <Button
            type="button"
            :label="t('CAPTAIN.ASSISTANTS.SETTINGS.SAVE')"
            size="sm"
            @click="save"
          />
          <Button
            type="button"
            :label="t('CAPTAIN.ASSISTANTS.SETTINGS.SAVE_BAR.DISCARD')"
            variant="ghost"
            color="slate"
            size="sm"
            @click="reset"
          />
        </template>
      </div>
    </div>
  </SettingsCard>
</template>

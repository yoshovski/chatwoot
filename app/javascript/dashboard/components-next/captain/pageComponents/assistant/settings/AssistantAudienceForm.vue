<script setup>
import { ref, computed, watch, useTemplateRef } from 'vue';
import { useI18n } from 'vue-i18n';
import RadioCard from 'dashboard/components-next/radioCard/RadioCard.vue';
import SegmentPicker from 'dashboard/components-next/Contacts/Customers/SegmentPicker.vue';
import SettingsCard from './SettingsCard.vue';
import SettingsSaveBar from './SettingsSaveBar.vue';
import { useSettingsSave } from './useSettingsSave';
import AudienceGroup from './audience/AudienceGroup.vue';
import { useAudienceFilterTypes } from './audience/useAudienceFilterTypes.js';

const props = defineProps({
  assistant: {
    type: Object,
    default: () => ({}),
  },
  save: {
    type: Function,
    default: null,
  },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();
const { filterTypes } = useAudienceFilterTypes();

const MODE = {
  EVERYONE: 'everyone',
  SPECIFIC: 'specific',
  SEGMENT: 'segment',
};

let uid = 0;
const nextId = () => {
  uid += 1;
  return `audience-root-${uid}`;
};

const hasConditions = node =>
  node && Object.prototype.hasOwnProperty.call(node, 'conditions');

const defaultRoot = () => ({ id: nextId(), operator: 'and', conditions: [] });

const root = ref(defaultRoot());
const mode = ref(MODE.EVERYONE);
const showEmptyAudienceError = ref(false);
const segmentId = ref('');
const audienceMode = audience => {
  if (audience?.segment_id) return MODE.SEGMENT;
  return audience ? MODE.SPECIFIC : MODE.EVERYONE;
};
const savedSnapshot = ref('');

const findOption = (filterType, value) =>
  filterType?.options?.find(option => String(option.id) === String(value));

const hydrateValues = (leaf, filterType) => {
  const raw = Array.isArray(leaf.values) ? leaf.values : [leaf.values];
  const inputType = filterType?.inputType;
  if (inputType === 'multiSelect') {
    return raw.map(
      value => findOption(filterType, value) ?? { id: value, name: value }
    );
  }
  if (['searchSelect', 'booleanSelect'].includes(inputType)) {
    return findOption(filterType, raw[0]) ?? { id: raw[0], name: raw[0] };
  }
  return raw[0] ?? '';
};

const hydrateNode = node => {
  if (hasConditions(node)) {
    return {
      id: nextId(),
      operator: node.operator || 'and',
      conditions: (node.conditions || []).map(hydrateNode),
    };
  }

  const filterType = filterTypes.value.find(
    type => type.attributeKey === node.attribute_key
  );
  return {
    id: nextId(),
    attributeKey: node.attribute_key,
    filterOperator: node.filter_operator,
    values: hydrateValues(node, filterType),
    attributeModel: filterType?.attributeModel || 'standard',
  };
};

const hydrateRoot = audience => {
  if (!audience || audience.segment_id) return defaultRoot();
  const hydrated = hydrateNode(audience);
  return hasConditions(hydrated)
    ? hydrated
    : { id: nextId(), operator: 'and', conditions: [hydrated] };
};

const serializeValues = values => {
  if (Array.isArray(values)) {
    return values[0]?.id ? values.map(value => value.id) : values;
  }
  if (values && typeof values === 'object') {
    return [values.id];
  }
  if (values === '' || values === null || values === undefined) {
    return [];
  }
  return [values];
};

const serializeNode = node => {
  if (hasConditions(node)) {
    return {
      operator: node.operator,
      conditions: node.conditions.map(serializeNode),
    };
  }
  return {
    attribute_key: node.attributeKey,
    filter_operator: node.filterOperator,
    values: serializeValues(node.values),
  };
};

const getAudiencePayload = () => {
  if (mode.value === MODE.SEGMENT)
    return segmentId.value ? { segment_id: segmentId.value } : null;
  const isSpecific = mode.value === MODE.SPECIFIC;
  return isSpecific && root.value.conditions.length
    ? serializeNode(root.value)
    : null;
};

const isDirty = computed(() => {
  const current = JSON.stringify([mode.value, getAudiencePayload()]);
  return current !== savedSnapshot.value;
});

const discard = () => {
  const audience = props.assistant?.config?.audience;
  root.value = hydrateRoot(audience);
  mode.value = audienceMode(audience);
  segmentId.value = audience?.segment_id || '';
  showEmptyAudienceError.value = false;
};

const groupRef = useTemplateRef('groupRef');

const handleSubmit = async () => {
  const isSpecific = mode.value === MODE.SPECIFIC;
  if (
    (mode.value === MODE.SEGMENT && !segmentId.value) ||
    (isSpecific && !root.value.conditions.length)
  ) {
    showEmptyAudienceError.value = true;
    return undefined;
  }

  showEmptyAudienceError.value = false;
  if (isSpecific && groupRef.value && !groupRef.value.validate()) {
    return undefined;
  }

  const audience = getAudiencePayload();
  const payload = {
    config: {
      ...props.assistant.config,
      audience,
    },
  };

  if (props.save) {
    return props.save(payload);
  }
  emit('submit', payload);
  return undefined;
};

watch(
  [
    () => props.assistant.id,
    () => JSON.stringify(props.assistant.config?.audience),
  ],
  () => {
    discard();
    savedSnapshot.value = JSON.stringify([
      mode.value,
      props.assistant.config?.audience || null,
    ]);
  },
  { immediate: true }
);

watch(
  () => root.value.conditions.length,
  () => {
    showEmptyAudienceError.value = false;
  }
);
const {
  isSaving,
  isSaved,
  saveError,
  save: saveChanges,
} = useSettingsSave(isDirty, handleSubmit);
</script>

<template>
  <div class="flex flex-col gap-6">
    <SettingsCard
      :title="t('CAPTAIN.AGENT_UX.CONFIGURATION.CURRENT')"
      :description="
        {
          everyone: t('CAPTAIN.ASSISTANTS.FORM.AUDIENCE.EVERYONE.LABEL'),
          segment: t('CUSTOMERS.AUDIENCE'),
          specific: t('CAPTAIN.ASSISTANTS.FORM.AUDIENCE.SPECIFIC.LABEL'),
        }[audienceMode(assistant.config?.audience)]
      "
    />
    <div class="flex flex-col gap-3" :inert="isSaving">
      <RadioCard
        :id="MODE.EVERYONE"
        :label="t('CAPTAIN.ASSISTANTS.FORM.AUDIENCE.EVERYONE.LABEL')"
        :description="
          t('CAPTAIN.ASSISTANTS.FORM.AUDIENCE.EVERYONE.DESC', {
            name: assistant.name,
          })
        "
        :is-active="mode === MODE.EVERYONE"
        @select="mode = MODE.EVERYONE"
      />
      <RadioCard
        :id="MODE.SEGMENT"
        :label="t('CUSTOMERS.AUDIENCE')"
        description=""
        :is-active="mode === MODE.SEGMENT"
        @select="mode = MODE.SEGMENT"
      >
        <SegmentPicker
          v-if="mode === MODE.SEGMENT"
          v-model="segmentId"
          class="w-full mt-2"
        />
      </RadioCard>
      <RadioCard
        :id="MODE.SPECIFIC"
        :label="t('CAPTAIN.ASSISTANTS.FORM.AUDIENCE.SPECIFIC.LABEL')"
        :description="
          t('CAPTAIN.ASSISTANTS.FORM.AUDIENCE.SPECIFIC.DESC', {
            name: assistant.name,
          })
        "
        :is-active="mode === MODE.SPECIFIC"
        @select="mode = MODE.SPECIFIC"
      >
        <AudienceGroup
          v-if="mode === MODE.SPECIFIC"
          ref="groupRef"
          v-model="root"
          is-root
          class="w-full mt-2"
          :filter-types="filterTypes"
        />
        <p v-if="showEmptyAudienceError" class="mt-2 text-sm text-n-ruby-11">
          {{ t('CAPTAIN.ASSISTANTS.FORM.AUDIENCE.EMPTY_ERROR') }}
        </p>
      </RadioCard>
    </div>

    <SettingsSaveBar
      :is-dirty="isDirty"
      :is-saving="isSaving"
      :is-saved="isSaved"
      :error="saveError"
      @save="saveChanges"
      @discard="discard"
    />
  </div>
</template>

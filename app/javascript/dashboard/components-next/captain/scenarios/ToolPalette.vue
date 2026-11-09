<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useRoute } from 'vue-router';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { vOnClickOutside } from '@vueuse/components';
import { useMapGetter } from 'dashboard/composables/store';
import ToolChip from './ToolChip.vue';
import ActionParamsDialog from './ActionParamsDialog.vue';
import DescribeActionDialog from './DescribeActionDialog.vue';
import ToolsDropdown from 'dashboard/components-next/captain/assistant/ToolsDropdown.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  SEPARATE_MESSAGE_PHRASE,
  groupTools,
  toolGroupLabel,
  needsFixedParams,
} from './builtInActions';

const props = defineProps({
  tools: {
    type: Array,
    default: null,
  },
});

const emit = defineEmits(['insertTool', 'insertText']);

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const storeCaptainTools = useMapGetter('captainTools/getRecords');
const contactAttributes = useMapGetter('attributes/getContactAttributes');

const PRIMARY_TOOL_IDS = [
  'faq_lookup',
  'catalog_product_search',
  'handoff',
  'add_private_note',
  'add_label_to_conversation',
];

const groupLabel = group => toolGroupLabel(group, t);

const paramsDialog = ref(null);
const describeDialog = ref(null);

const availableTools = computed(() => {
  return props.tools || storeCaptainTools.value || [];
});

const primaryTools = computed(() => {
  return PRIMARY_TOOL_IDS.map(id =>
    availableTools.value.find(item => item.id === id)
  ).filter(Boolean);
});

const showMoreDropdown = ref(false);
const searchQuery = ref('');

const updateContactAttributeTool = computed(() =>
  availableTools.value.find(tool => tool.id === 'update_contact_attribute')
);

// Read inserts a phrase that names the attribute the prompt lists; Update inserts the built-in action.
const contactPropertyItems = computed(() =>
  (contactAttributes.value || []).flatMap(attribute => {
    const name = attribute.attributeDisplayName;
    const key = attribute.attributeKey;
    const read = {
      id: `read:${key}`,
      kind: 'text',
      title: t('CAPTAIN.ASSISTANTS.SCENARIOS.PALETTE.PROPERTY.READ', { name }),
      description: key,
      text: t('CAPTAIN.ASSISTANTS.SCENARIOS.PALETTE.PROPERTY.READ_TEXT', {
        name,
        key,
      }),
    };
    if (!updateContactAttributeTool.value) return [read];
    return [
      read,
      {
        id: `update:${key}`,
        kind: 'property',
        title: t('CAPTAIN.ASSISTANTS.SCENARIOS.PALETTE.PROPERTY.UPDATE', {
          name,
        }),
        description: key,
        emoji: updateContactAttributeTool.value.emoji,
        key,
        name,
      },
    ];
  })
);

const replyShapeItems = computed(() => [
  {
    id: 'reply:separate_message',
    kind: 'text',
    title: t('CAPTAIN.ASSISTANTS.SCENARIOS.PALETTE.REPLY_SHAPE.SEPARATE'),
    description: t(
      'CAPTAIN.ASSISTANTS.SCENARIOS.PALETTE.REPLY_SHAPE.SEPARATE_DESCRIPTION'
    ),
    text: SEPARATE_MESSAGE_PHRASE,
  },
]);

const withGroupLabel = (items, label) =>
  items.map((item, index) =>
    index === 0 ? { ...item, groupLabel: label } : item
  );

const matches = (item, query) =>
  !query ||
  [item.title, item.description, item.id].some(value =>
    value?.toLowerCase().includes(query)
  );

const filteredDropdownTools = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();
  const tools = availableTools.value.filter(tool => matches(tool, query));
  const describe = {
    id: 'describe_action',
    kind: 'describe',
    emoji: '✨',
    title: t('CAPTAIN.ASSISTANTS.SCENARIOS.DESCRIBE.ITEM'),
    description: t('CAPTAIN.ASSISTANTS.SCENARIOS.DESCRIBE.ITEM_DESCRIPTION'),
  };
  return [
    ...(query ? [] : [describe]),
    ...groupTools(tools, groupLabel),
    ...withGroupLabel(
      contactPropertyItems.value.filter(item => matches(item, query)),
      t('CAPTAIN.ASSISTANTS.SCENARIOS.PALETTE.GROUPS.CONTACT_PROPERTIES')
    ),
    ...withGroupLabel(
      replyShapeItems.value.filter(item => matches(item, query)),
      t('CAPTAIN.ASSISTANTS.SCENARIOS.PALETTE.GROUPS.REPLY_SHAPE')
    ),
  ];
});

// Templates are edited on the Tools & MCP page; it opens next to the scenario so the step isn't lost.
const openTemplates = () => {
  const { accountId, assistantId } = route.params;
  window.open(
    frontendURL(`accounts/${accountId}/captain/${assistantId}/tools`),
    '_blank',
    'noopener'
  );
};

const configure = (tool, preset = {}) => {
  paramsDialog.value?.open(tool, preset);
};

const select = item => {
  if (item.kind === 'describe') {
    describeDialog.value?.open();
  } else if (item.kind === 'text') {
    emit('insertText', item.text);
  } else if (item.kind === 'property') {
    configure(updateContactAttributeTool.value, { key: item.key });
  } else if (needsFixedParams(item)) {
    configure(item);
  } else {
    emit('insertTool', item);
  }
};

const onSelectDropdownItem = (idx, tool) => {
  const selected = tool || filteredDropdownTools.value[idx];
  if (selected) select(selected);
  showMoreDropdown.value = false;
  searchQuery.value = '';
};

const onSearchDropdown = q => {
  searchQuery.value = q;
};

onMounted(() => {
  if (!(contactAttributes.value || []).length) store.dispatch('attributes/get');
});

defineExpose({ configure });
</script>

<template>
  <div class="flex items-center gap-1.5 flex-wrap text-xs text-n-slate-11 py-1">
    <span class="font-medium text-n-slate-11">
      {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.PALETTE.TITLE') }}
    </span>

    <ToolChip
      v-for="tool in primaryTools"
      :key="tool.id"
      :tool="tool"
      clickable
      @click="select(tool)"
    />

    <div
      v-if="availableTools.length > 0"
      v-on-click-outside="() => (showMoreDropdown = false)"
      class="relative inline-block"
    >
      <Button
        type="button"
        xs
        ghost
        slate
        icon="i-lucide-chevron-down"
        trailing-icon
        :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.PALETTE.MORE')"
        class="!text-xs !py-0.5 !px-2 rounded-full border border-n-weak hover:bg-n-alpha-2"
        data-test="palette-more"
        @click="showMoreDropdown = !showMoreDropdown"
      />

      <ToolsDropdown
        v-if="showMoreDropdown"
        :items="filteredDropdownTools"
        show-search
        :search-placeholder="t('CAPTAIN.ASSISTANTS.SCENARIOS.PALETTE.SEARCH')"
        class="top-8 ltr:left-0 rtl:right-0 shadow-lg"
        @select="onSelectDropdownItem"
        @search="onSearchDropdown"
      />
    </div>

    <DescribeActionDialog
      ref="describeDialog"
      @insert="tool => emit('insertTool', tool)"
    />
    <ActionParamsDialog
      ref="paramsDialog"
      @insert="tool => emit('insertTool', tool)"
      @new-template="openTemplates"
    />
  </div>
</template>

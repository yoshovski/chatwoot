<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';
import { useMapGetter } from 'dashboard/composables/store';
import ToolChip from './ToolChip.vue';
import ToolsDropdown from 'dashboard/components-next/captain/assistant/ToolsDropdown.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  tools: {
    type: Array,
    default: null,
  },
});

const emit = defineEmits(['insertTool']);

const { t } = useI18n();
const storeCaptainTools = useMapGetter('captainTools/getRecords');

const PRIMARY_TOOL_IDS = [
  'faq_lookup',
  'catalog_product_search',
  'handoff',
  'add_private_note',
  'add_label_to_conversation',
];

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

const filteredDropdownTools = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();
  return availableTools.value.filter(tool => {
    if (!query) return true;
    return (
      tool.title?.toLowerCase().includes(query) ||
      tool.description?.toLowerCase().includes(query) ||
      tool.id?.toLowerCase().includes(query)
    );
  });
});

const onSelectChip = tool => {
  emit('insertTool', tool);
};

const onSelectDropdownItem = (idx, tool) => {
  const selected = tool || filteredDropdownTools.value[idx];
  if (selected) {
    emit('insertTool', selected);
  }
  showMoreDropdown.value = false;
  searchQuery.value = '';
};

const onSearchDropdown = q => {
  searchQuery.value = q;
};
</script>

<template>
  <div class="flex items-center gap-1.5 flex-wrap text-xs text-n-slate-11 py-1">
    <span class="font-medium text-n-slate-11">
      {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.PALETTE.TITLE', 'Add a tool:') }}
    </span>

    <ToolChip
      v-for="tool in primaryTools"
      :key="tool.id"
      :tool="tool"
      clickable
      @click="onSelectChip(tool)"
    />

    <div
      v-if="availableTools.length > 0"
      v-on-click-outside="() => (showMoreDropdown = false)"
      class="relative inline-block"
    >
      <Button
        xs
        ghost
        slate
        icon="i-lucide-chevron-down"
        trailing-icon
        :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.PALETTE.MORE', 'More tools')"
        class="!text-xs !py-0.5 !px-2 rounded-full border border-n-weak hover:bg-n-alpha-2"
        @click="showMoreDropdown = !showMoreDropdown"
      />

      <ToolsDropdown
        v-if="showMoreDropdown"
        :items="filteredDropdownTools"
        show-search
        :search-placeholder="
          t('CAPTAIN.ASSISTANTS.SCENARIOS.PALETTE.SEARCH', 'Search tools...')
        "
        class="top-8 ltr:left-0 rtl:right-0 shadow-lg"
        @select="onSelectDropdownItem"
        @search="onSearchDropdown"
      />
    </div>
  </div>
</template>

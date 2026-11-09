<script setup>
import { ref, computed, watch } from 'vue';
import ToolsDropdown from 'dashboard/components-next/captain/assistant/ToolsDropdown.vue';
import { useKeyboardNavigableList } from 'dashboard/composables/useKeyboardNavigableList';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store.js';
import {
  groupTools,
  toolGroupLabel,
} from 'dashboard/components-next/captain/scenarios/builtInActions';

const props = defineProps({
  searchKey: {
    type: String,
    default: '',
  },
  menuPosition: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['selectTool']);

const { t } = useI18n();
const tools = useMapGetter('captainTools/getRecords');

const selectedIndex = ref(0);

const filteredTools = computed(() => {
  const search = props.searchKey?.trim().toLowerCase() || '';

  const matches = tools.value.filter(tool =>
    tool.title.toLowerCase().includes(search)
  );
  // Built-in actions, your actions, MCP tools: the same groups as the palette.
  return groupTools(matches, group => toolGroupLabel(group, t));
});

const adjustScroll = () => {};

const onSelect = (idx, tool) => {
  if (typeof idx === 'number') selectedIndex.value = idx;
  const selected = tool || filteredTools.value[selectedIndex.value];
  if (selected) {
    emit('selectTool', selected);
  }
};

useKeyboardNavigableList({
  items: filteredTools,
  onSelect,
  adjustScroll,
  selectedIndex,
});

watch(filteredTools, newListOfTools => {
  if (newListOfTools.length < selectedIndex.value + 1) {
    selectedIndex.value = 0;
  }
});
</script>

<template>
  <ToolsDropdown
    v-if="filteredTools.length"
    :items="filteredTools"
    :selected-index="selectedIndex"
    :style="
      menuPosition ? { top: menuPosition.top, left: menuPosition.left } : null
    "
    :class="menuPosition ? '' : 'bottom-20'"
    @select="onSelect"
  />
  <template v-else />
</template>

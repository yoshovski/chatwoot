<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';

const props = defineProps({
  toolId: {
    type: String,
    default: '',
  },
  tool: {
    type: Object,
    default: null,
  },
  clickable: {
    type: Boolean,
    default: false,
  },
  removable: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['click', 'remove']);

const { t } = useI18n();
const captainTools = useMapGetter('captainTools/getRecords');

const effectiveId = computed(() => props.tool?.id || props.toolId || '');

const matchedTool = computed(() => {
  if (props.tool && props.tool.title) return props.tool;
  return (captainTools.value || []).find(tool => tool.id === effectiveId.value);
});

const isAvailable = computed(() => Boolean(matchedTool.value));

const title = computed(() => {
  return matchedTool.value?.title || effectiveId.value;
});

const emoji = computed(() => {
  return matchedTool.value?.emoji || '';
});

const tooltip = computed(() => {
  if (isAvailable.value) {
    return matchedTool.value?.description || '';
  }
  return t('CAPTAIN.ASSISTANTS.SCENARIOS.TOOLS.UNAVAILABLE');
});

const handleClick = () => {
  if (props.clickable) {
    emit(
      'click',
      matchedTool.value || { id: effectiveId.value, title: title.value }
    );
  }
};
</script>

<template>
  <span
    v-tooltip.top="{ content: tooltip, delay: { show: 200, hide: 0 } }"
    class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium transition-colors select-none"
    :class="[
      isAvailable
        ? 'bg-n-iris-3 text-n-iris-11 border border-n-iris-4'
        : 'bg-n-alpha-2 text-n-slate-11 border border-n-weak',
      clickable
        ? 'cursor-pointer hover:brightness-95 active:scale-95'
        : 'cursor-default',
    ]"
    @click="handleClick"
  >
    <span v-if="emoji" class="text-xs leading-none">{{ emoji }}</span>
    <span class="truncate">{{ title }}</span>
    <button
      v-if="removable"
      type="button"
      class="-me-1 inline-flex items-center justify-center rounded-full p-0.5 hover:bg-n-alpha-2"
      :aria-label="t('CAPTAIN.ASSISTANTS.SCENARIOS.FORM.TOOLS.REMOVE', { tool: title })"
      @click.stop="emit('remove')"
    >
      <span class="i-lucide-x size-3" />
    </button>
  </span>
</template>

<script setup>
import { ref, watch, nextTick } from 'vue';

const props = defineProps({
  items: {
    type: Array,
    required: true,
  },
  selectedIndex: {
    type: Number,
    default: 0,
  },
  showSearch: {
    type: Boolean,
    default: false,
  },
  searchPlaceholder: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['select', 'search']);

const toolsDropdownRef = ref(null);
const searchQuery = ref('');

const onItemClick = idx => emit('select', idx, props.items[idx]);

const handleSearch = event => {
  searchQuery.value = event.target.value;
  emit('search', searchQuery.value);
};

watch(
  () => props.selectedIndex,
  () => {
    nextTick(() => {
      const el = toolsDropdownRef.value?.querySelector(
        `#tool-item-${props.selectedIndex}`
      );
      if (el) {
        el.scrollIntoView({ block: 'nearest', behavior: 'auto' });
      }
    });
  },
  { immediate: true }
);
</script>

<template>
  <div
    ref="toolsDropdownRef"
    class="w-[22.5rem] p-2 flex flex-col gap-1 z-50 absolute rounded-xl bg-n-alpha-3 shadow outline outline-1 outline-n-weak backdrop-blur-[50px] max-h-[20rem] overflow-y-auto"
  >
    <div v-if="showSearch" class="p-1 pb-2 border-b border-n-weak">
      <input
        :value="searchQuery"
        type="text"
        :placeholder="searchPlaceholder || 'Search tools...'"
        class="w-full px-2.5 py-1.5 text-xs rounded-lg bg-n-alpha-black2 border border-n-weak text-n-slate-12 placeholder-n-slate-9 outline-none focus:border-n-brand"
        @input="handleSearch"
      />
    </div>
    <div
      v-for="(tool, idx) in items"
      :id="`tool-item-${idx}`"
      :key="tool.id || idx"
      :class="{ 'bg-n-alpha-black2': idx === selectedIndex }"
      class="flex flex-col gap-0.5 rounded-md py-1.5 px-2 cursor-pointer hover:bg-n-alpha-black2"
      @click="onItemClick(idx)"
    >
      <div class="flex items-center gap-1.5">
        <span v-if="tool.emoji" class="text-sm leading-none">{{
          tool.emoji
        }}</span>
        <span class="text-n-slate-12 font-medium text-sm">{{
          tool.title
        }}</span>
      </div>
      <span class="text-n-slate-11 text-xs">{{ tool.description }}</span>
    </div>
  </div>
</template>

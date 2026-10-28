<script setup>
import { computed, ref } from 'vue';
import { pathFromSegments } from './actionForm';

// One node of a test response. Clicking a key (or a value) asks to save that node as an output.
const props = defineProps({
  value: { type: [Object, Array, String, Number, Boolean], default: null },
  name: { type: [String, Number], default: null },
  segments: { type: Array, default: () => [] },
  savedPaths: { type: Array, default: () => [] },
  depth: { type: Number, default: 0 },
});

const emit = defineEmits(['pick']);

const AUTO_EXPANDED_DEPTH = 3;

const isBranch = computed(
  () => props.value !== null && typeof props.value === 'object'
);
const isExpanded = ref(props.depth < AUTO_EXPANDED_DEPTH);
const entries = computed(() =>
  Array.isArray(props.value)
    ? props.value.map((child, index) => [index, child])
    : Object.entries(props.value || {})
);
const isSaved = computed(
  () =>
    props.segments.length > 0 &&
    props.savedPaths.includes(pathFromSegments(props.segments))
);
const summary = computed(() =>
  Array.isArray(props.value) ? `[${props.value.length}]` : '{…}'
);
const displayValue = computed(() =>
  typeof props.value === 'string' ? `"${props.value}"` : String(props.value)
);

const pick = () => {
  if (!props.segments.length) return;
  emit('pick', { segments: props.segments, value: props.value });
};
</script>

<template>
  <div class="font-mono text-xs leading-6">
    <div
      v-if="name !== null"
      class="flex items-center gap-1 px-1 rounded group hover:bg-n-blue-2"
      data-test="json-node"
    >
      <button
        v-if="isBranch"
        type="button"
        class="text-n-slate-10 size-4 shrink-0"
        :class="isExpanded ? 'i-lucide-chevron-down' : 'i-lucide-chevron-right'"
        @click="isExpanded = !isExpanded"
      />
      <span v-else class="size-4 shrink-0" />
      <button
        type="button"
        class="text-n-slate-11 whitespace-nowrap shrink-0 hover:text-n-blue-11 hover:underline"
        data-test="json-key"
        @click="pick"
      >
        {{ typeof name === 'number' ? `[${name}]` : name }}:
      </button>
      <span v-if="isBranch" class="text-n-slate-10">{{ summary }}</span>
      <button
        v-else
        type="button"
        class="min-w-0 truncate text-n-slate-12 hover:text-n-blue-11"
        data-test="json-value"
        @click="pick"
      >
        {{ displayValue }}
      </button>
      <span
        v-if="isSaved"
        class="i-lucide-check size-3.5 text-n-teal-10 shrink-0"
        data-test="json-saved"
      />
    </div>
    <div
      v-if="isBranch && (isExpanded || name === null)"
      :class="{ 'ps-4': name !== null }"
    >
      <JsonTree
        v-for="[childName, child] in entries"
        :key="childName"
        :name="childName"
        :value="child"
        :segments="[...segments, childName]"
        :saved-paths="savedPaths"
        :depth="depth + 1"
        @pick="payload => emit('pick', payload)"
      />
    </div>
  </div>
</template>

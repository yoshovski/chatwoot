<script setup>
import { computed } from 'vue';
import { templateParts } from './actionForm';

// Shows a template with each {{ variable }} as a small tag.
const props = defineProps({
  text: { type: String, default: '' },
});

const parts = computed(() => templateParts(props.text));
</script>

<template>
  <span class="truncate">
    <template v-for="(part, index) in parts" :key="index">
      <span
        v-if="part.variable"
        class="px-1.5 py-px mx-0.5 rounded-md bg-n-blue-3 text-n-blue-11 font-sans text-xs"
      >
        {{ part.variable.replace(/^outputs\./, '') }}
      </span>
      <template v-else>{{ part.text }}</template>
    </template>
  </span>
</template>

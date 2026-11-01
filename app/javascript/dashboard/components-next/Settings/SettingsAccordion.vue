<script setup>
import { ref } from 'vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  title: {
    type: String,
    required: true,
  },
  defaultOpen: {
    type: Boolean,
    default: true,
  },
});

const isOpen = ref(props.defaultOpen);
</script>

<template>
  <button
    v-bind="$attrs"
    type="button"
    class="flex items-center justify-between w-full gap-2 pb-2 pt-4 border-0 border-t border-solid border-n-weak bg-transparent text-start cursor-pointer"
    :aria-expanded="isOpen"
    @click="isOpen = !isOpen"
  >
    <span class="text-heading-2 text-n-slate-12 w-full">
      {{ title }}
    </span>
    <Icon
      icon="i-lucide-chevron-down"
      class="size-4 shrink-0 text-n-slate-11 transition-transform"
      :class="{ 'rotate-180': isOpen }"
    />
  </button>
  <div v-if="isOpen" class="w-full space-y-4 pt-4 mb-4">
    <slot />
  </div>
</template>

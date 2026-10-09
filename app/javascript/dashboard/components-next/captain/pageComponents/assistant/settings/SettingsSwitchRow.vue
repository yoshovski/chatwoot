<script setup>
import Switch from 'dashboard/components-next/switch/Switch.vue';

defineProps({
  title: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    default: '',
  },
});

const modelValue = defineModel({ type: Boolean, default: false });
</script>

<template>
  <div class="flex items-start justify-between gap-4 py-3.5">
    <div class="flex flex-col gap-0.5 min-w-0">
      <span class="text-sm font-medium text-n-slate-12">{{ title }}</span>
      <span v-if="description" class="text-sm text-n-slate-11">
        {{ description }}
      </span>
      <slot />
    </div>
    <Switch v-model="modelValue" :aria-label="title" class="mt-0.5" />
  </div>
</template>

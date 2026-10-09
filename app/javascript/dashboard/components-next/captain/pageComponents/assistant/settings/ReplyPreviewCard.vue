<script setup>
import Switch from 'dashboard/components-next/switch/Switch.vue';

defineProps({
  title: {
    type: String,
    required: true,
  },
  note: {
    type: String,
    default: '',
  },
});

const modelValue = defineModel({ type: Boolean, default: false });
</script>

<template>
  <div
    class="flex flex-col gap-3 p-4 rounded-xl outline bg-n-solid-1 transition-[outline-color]"
    :class="
      modelValue ? 'outline-2 outline-n-brand' : 'outline-1 outline-n-weak'
    "
  >
    <div class="flex items-center justify-between gap-2">
      <span class="text-sm font-medium text-n-slate-12">{{ title }}</span>
      <Switch v-model="modelValue" :aria-label="title" />
    </div>
    <div
      class="flex flex-col gap-2 p-3 text-sm rounded-lg bg-n-slate-2 text-n-slate-12"
      aria-hidden="true"
    >
      <slot name="preview" />
    </div>
    <slot>
      <span v-if="note" class="text-xs text-n-slate-11">{{ note }}</span>
    </slot>
  </div>
</template>

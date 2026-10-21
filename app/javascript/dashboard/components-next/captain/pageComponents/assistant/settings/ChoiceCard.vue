<script setup>
defineProps({
  name: {
    type: String,
    required: true,
  },
  value: {
    type: String,
    required: true,
  },
  label: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    default: '',
  },
  icon: {
    type: String,
    default: '',
  },
  isActive: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['select']);
</script>

<template>
  <label
    class="flex items-center gap-3 px-4 py-3 transition-colors cursor-pointer rounded-xl outline bg-n-solid-1 focus-within:has-[:focus-visible]:ring-2 focus-within:has-[:focus-visible]:ring-n-strong"
    :class="
      isActive
        ? 'outline-2 outline-n-blue-9 bg-n-blue-1'
        : 'outline-1 outline-n-weak hover:outline-n-strong'
    "
  >
    <span
      v-if="icon"
      class="flex items-center justify-center rounded-lg size-9 shrink-0"
      :class="
        isActive ? 'bg-n-blue-3 text-n-blue-11' : 'bg-n-slate-3 text-n-slate-11'
      "
    >
      <span :class="icon" class="size-4" aria-hidden="true" />
    </span>
    <span class="flex flex-col flex-1 min-w-0 gap-0.5">
      <span class="text-sm font-medium text-n-slate-12">{{ label }}</span>
      <span v-if="description" class="text-xs text-n-slate-11">
        {{ description }}
      </span>
    </span>
    <input
      type="radio"
      :name="name"
      :value="value"
      :checked="isActive"
      class="shrink-0 accent-n-blue-9 size-4"
      @change="emit('select', value)"
    />
  </label>
</template>

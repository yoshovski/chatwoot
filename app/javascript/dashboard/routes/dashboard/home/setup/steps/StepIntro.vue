<script setup>
defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
});
</script>

<template>
  <div class="flex flex-col gap-1">
    <h2 class="mb-0 text-base font-medium text-n-slate-12">{{ title }}</h2>
    <p v-if="description" class="mb-0 text-sm text-n-slate-11">
      {{ description }}
    </p>
  </div>
</template>

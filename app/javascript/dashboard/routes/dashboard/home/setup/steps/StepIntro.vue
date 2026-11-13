<script setup>
defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
});
</script>

<template>
  <div class="flex flex-col gap-2">
    <h1
      class="mb-0 font-display text-2xl font-semibold tracking-display text-n-slate-12 sm:text-3xl"
    >
      {{ title }}
    </h1>
    <p v-if="description" class="mb-0 text-base text-n-slate-11">
      {{ description }}
    </p>
  </div>
</template>

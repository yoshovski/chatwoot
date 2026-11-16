<script setup>
defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
});
</script>

<template>
  <section
    class="flex flex-col gap-5 rounded-card bg-n-solid-2 p-6 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
  >
    <header class="flex flex-col gap-1 border-b border-n-weak pb-4">
      <h3 class="mb-0 text-heading-2 text-n-slate-12">{{ title }}</h3>
      <p v-if="description" class="mb-0 text-body-main text-n-slate-11">
        {{ description }}
      </p>
    </header>
    <slot />
  </section>
</template>

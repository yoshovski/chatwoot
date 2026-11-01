<script setup>
defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
});
</script>

<template>
  <section
    class="flex flex-col gap-4 rounded-xl bg-n-solid-1 p-5 outline outline-1 -outline-offset-1 outline-n-weak"
  >
    <header class="flex flex-col gap-1">
      <h3 class="mb-0 text-heading-2 text-n-slate-12">{{ title }}</h3>
      <p v-if="description" class="mb-0 text-body-main text-n-slate-11">
        {{ description }}
      </p>
    </header>
    <slot />
  </section>
</template>

<script setup>
defineProps({
  title: {
    type: String,
    default: '',
  },
  description: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <section
    class="flex flex-col px-5 py-4 rounded-xl outline outline-1 outline-n-weak bg-n-solid-1"
  >
    <header v-if="title" class="flex flex-col gap-0.5 pb-1">
      <h3 class="text-sm font-semibold text-n-slate-12">{{ title }}</h3>
      <p v-if="description" class="mb-0 text-sm text-n-slate-11">
        {{ description }}
      </p>
    </header>
    <div class="flex flex-col divide-y divide-n-weak">
      <slot />
    </div>
  </section>
</template>

<script setup>
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  title: { type: String, required: true },
  linkLabel: { type: String, default: '' },
  to: { type: [Object, String], default: null },
});
</script>

<template>
  <section
    class="flex min-w-0 flex-col gap-4 rounded-xl bg-n-solid-2 p-5 outline outline-1 -outline-offset-1 outline-n-container"
  >
    <header class="flex items-center justify-between gap-3">
      <h2 class="text-sm font-medium text-n-slate-12">{{ title }}</h2>
      <router-link
        v-if="to && linkLabel"
        :to="to"
        class="inline-flex shrink-0 items-center gap-1 text-xs font-medium text-n-slate-11 hover:text-n-blue-11"
      >
        {{ linkLabel }}
        <Icon icon="i-lucide-arrow-right" class="size-3.5" />
      </router-link>
    </header>
    <slot />
  </section>
</template>

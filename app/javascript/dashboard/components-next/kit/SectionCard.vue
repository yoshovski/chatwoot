<script setup>
import Icon from 'dashboard/components-next/icon/Icon.vue';

// A white card with a title and an optional "see all" link. The body is the default slot.
defineProps({
  title: { type: String, default: '' },
  linkLabel: { type: String, default: '' },
  to: { type: [Object, String], default: null },
});
</script>

<template>
  <section
    class="flex min-w-0 flex-col gap-4 rounded-card bg-n-solid-2 p-5 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
  >
    <header
      v-if="title || $slots.actions"
      class="flex items-center justify-between gap-3"
    >
      <h2
        class="mb-0 font-display text-base font-semibold tracking-display text-n-slate-12"
      >
        {{ title }}
      </h2>
      <slot name="actions">
        <router-link
          v-if="to && linkLabel"
          :to="to"
          class="inline-flex shrink-0 items-center gap-1 text-xs font-medium text-n-slate-11 hover:text-n-blue-11"
        >
          {{ linkLabel }}
          <Icon icon="i-lucide-arrow-right" class="size-3.5" />
        </router-link>
      </slot>
    </header>
    <slot />
  </section>
</template>

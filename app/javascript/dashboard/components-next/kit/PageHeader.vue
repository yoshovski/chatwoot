<script setup>
// Title, one help line and the page's primary action on the right. `band` turns it into the gradient
// welcome band used by Home.
defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
  band: { type: Boolean, default: false },
});
</script>

<template>
  <header
    class="flex flex-wrap items-center gap-4"
    :class="
      band
        ? 'rounded-card bg-[image:var(--co-hero-bg)] p-6 shadow-card'
        : 'pb-1'
    "
  >
    <div class="me-auto flex min-w-0 flex-col gap-1">
      <h1
        class="mb-0 font-display text-2xl font-semibold tracking-display"
        :class="band ? 'text-white' : 'text-n-slate-12'"
      >
        {{ title }}
      </h1>
      <p
        v-if="description"
        class="mb-0 text-sm"
        :class="band ? 'text-white' : 'text-n-slate-11'"
      >
        {{ description }}
      </p>
    </div>
    <div v-if="$slots.action" class="flex shrink-0 items-center gap-2">
      <slot name="action" />
    </div>
  </header>
</template>

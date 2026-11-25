<script setup>
// The frame every page uses: neutral canvas, centred column (`64rem` default or `80rem` wide for dense tables).
defineProps({
  workspace: Boolean,
  size: {
    type: String,
    default: 'default',
    validator: value => ['default', 'wide'].includes(value),
  },
});
</script>

<template>
  <section class="flex h-full w-full flex-col overflow-y-auto bg-n-background">
    <div
      class="mx-auto flex w-full flex-col gap-5 px-4 py-6 sm:px-6 sm:py-8"
      :class="[
        size === 'wide' ? 'max-w-[80rem]' : 'max-w-[64rem]',
        { 'workspace-content': workspace },
      ]"
    >
      <slot name="header" />
      <slot />
    </div>
  </section>
</template>

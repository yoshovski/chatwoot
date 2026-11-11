<script setup>
// The frame every page uses: tinted background, one centred column of 64 rem, the header first.
</script>

<template>
  <section class="flex h-full w-full flex-col overflow-y-auto bg-n-background">
    <div
      class="mx-auto flex w-full max-w-[64rem] flex-col gap-5 px-4 py-6 sm:px-6 sm:py-8"
    >
      <slot name="header" />
      <slot />
    </div>
  </section>
</template>

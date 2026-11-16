<script setup>
// Settings editor on the left, a sticky customer-facing preview on the right.
// Below xl the preview stacks under the form so it stays reachable.
</script>

<template>
  <div
    class="grid min-w-0 items-start gap-8"
    :class="
      $slots.preview ? 'xl:grid-cols-[minmax(0,1fr)_19rem]' : 'max-w-[48rem]'
    "
  >
    <div class="flex flex-col min-w-0 gap-6">
      <slot />
    </div>
    <aside
      v-if="$slots.preview"
      class="flex min-w-0 flex-col gap-3 xl:sticky xl:top-2"
    >
      <slot name="preview" />
    </aside>
  </div>
</template>

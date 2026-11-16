<script setup>
defineProps({
  contentSized: { type: Boolean, default: false },
  isLoading: {
    type: Boolean,
    default: false,
  },
  noRecordsFound: {
    type: Boolean,
    default: false,
  },
  loadingMessage: {
    type: String,
    default: '',
  },
  noRecordsMessage: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <div
    data-co-settings-bridge
    class="flex flex-col w-full gap-5"
    :class="contentSized ? 'h-auto' : 'h-full'"
  >
    <slot name="header" />
    <!-- Added to render any templates that should be rendered before body -->
    <main>
      <slot name="preBody" />
      <slot v-if="isLoading" name="loading">
        <woot-loading-state :message="loadingMessage" />
      </slot>
      <div
        v-else-if="noRecordsFound"
        class="flex items-center justify-center rounded-card bg-n-solid-2 p-12 text-center text-sm text-n-slate-11 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
      >
        {{ noRecordsMessage }}
      </div>
      <slot v-else name="body" />
      <!-- Do not delete the slot below. It is required to render anything that is not defined in the above slots. -->
      <slot />
    </main>
  </div>
</template>

<script setup>
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

// The one form: one column of at most 40 rem with grouped cards (SectionCard) in the default slot,
// and a Save bar that sticks to the bottom. `saved` shows "Saved" next to the button.
defineProps({
  saveLabel: { type: String, required: true },
  savedLabel: { type: String, default: '' },
  saving: { type: Boolean, default: false },
  saved: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
});

const emit = defineEmits(['save']);
</script>

<template>
  <form
    class="flex w-full max-w-[40rem] flex-col gap-5"
    @submit.prevent="emit('save')"
  >
    <slot />
    <div
      class="sticky bottom-0 z-10 flex items-center gap-3 rounded-card bg-n-solid-2 px-5 py-3 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
    >
      <div class="me-auto min-w-0 text-sm text-n-slate-11">
        <slot name="status" />
      </div>
      <span
        v-if="saved && savedLabel"
        class="inline-flex items-center gap-1 text-sm font-medium text-n-teal-11"
        role="status"
      >
        <Icon icon="i-lucide-check" class="size-4" />
        {{ savedLabel }}
      </span>
      <Button
        type="submit"
        size="sm"
        :label="saveLabel"
        :is-loading="saving"
        :disabled="disabled || saving"
      />
    </div>
  </form>
</template>

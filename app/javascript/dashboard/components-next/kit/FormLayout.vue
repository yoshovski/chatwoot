<script setup>
import { computed, inject, ref, watch } from 'vue';
import { matchedRouteKey, onBeforeRouteLeave } from 'vue-router';
import { useEventListener } from '@vueuse/core';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  saveLabel: { type: String, required: true },
  savedLabel: { type: String, default: '' },
  saving: { type: Boolean, default: false },
  saved: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
  // Omitted for legacy forms. Explicit-save callers compare the draft to the saved data.
  dirty: { type: Boolean, default: undefined },
  error: { type: String, default: '' },
});

const emit = defineEmits(['save', 'discard']);
const form = ref(null);
const leaveDialog = ref(null);
const canSave = computed(
  () => !props.disabled && !props.saving && props.dirty !== false
);

const save = () => {
  if (canSave.value) emit('save');
};

watch(
  () => props.error,
  error => {
    if (error) form.value?.querySelector('[aria-invalid="true"]')?.focus();
  },
  { flush: 'post' }
);

useEventListener(
  computed(() => (props.dirty || props.saving ? window : null)),
  'beforeunload',
  event => {
    event.preventDefault();
    event.returnValue = '';
  }
);

let pendingLeave;
let resolveLeave;

const finishLeave = allowed => {
  resolveLeave?.(allowed);
  resolveLeave = undefined;
  pendingLeave = undefined;
};

const confirmLeave = () => {
  finishLeave(true);
  leaveDialog.value.close();
};

if (inject(matchedRouteKey, null)) {
  onBeforeRouteLeave(() => {
    if (props.saving) return false;
    if (!props.dirty) return true;
    if (!pendingLeave) {
      pendingLeave = new Promise(resolve => {
        resolveLeave = resolve;
      });
      leaveDialog.value.open();
    }
    return pendingLeave;
  });
}
</script>

<template>
  <form
    ref="form"
    class="flex w-full min-w-0 max-w-[40rem] flex-col gap-5 pb-4"
    @submit.prevent="save"
  >
    <slot />
    <div
      class="flex flex-wrap items-center gap-3 rounded-card bg-n-solid-2 px-5 py-3 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
    >
      <div
        v-if="$slots.status || dirty"
        class="me-auto min-w-0 break-words text-sm text-n-slate-11"
      >
        <slot name="status">
          {{ $t('GENERAL.FORM.UNSAVED') }}
        </slot>
      </div>
      <span
        v-if="savedLabel"
        class="inline-flex min-w-0 items-center gap-1 break-words text-sm font-medium text-n-teal-11"
        role="status"
      >
        <template v-if="saved && !dirty && !saving && !error">
          <Icon icon="i-lucide-check" class="size-4 shrink-0" />
          {{ savedLabel }}
        </template>
      </span>
      <div class="ms-auto flex min-w-0 flex-wrap items-center gap-2">
        <Button
          v-if="dirty"
          type="button"
          size="sm"
          variant="ghost"
          color="slate"
          :label="$t('GENERAL.DISCARD')"
          :disabled="saving"
          @click="emit('discard')"
        />
        <Button
          type="submit"
          size="sm"
          class="max-w-full !whitespace-normal"
          :label="saveLabel"
          :is-loading="saving"
          :disabled="!canSave"
        />
      </div>
      <div
        role="alert"
        :class="
          error ? 'basis-full break-words text-sm text-n-ruby-11' : 'sr-only'
        "
      >
        {{ error }}
      </div>
    </div>
    <Dialog
      v-if="dirty !== undefined"
      ref="leaveDialog"
      type="alert"
      :title="$t('GENERAL.FORM.UNSAVED')"
      :description="$t('GENERAL.FORM.LEAVE_DESCRIPTION')"
      :cancel-button-label="$t('GENERAL.FORM.KEEP_EDITING')"
      :confirm-button-label="$t('GENERAL.FORM.DISCARD_AND_LEAVE')"
      @confirm="confirmLeave"
      @close="finishLeave(false)"
    />
  </form>
</template>

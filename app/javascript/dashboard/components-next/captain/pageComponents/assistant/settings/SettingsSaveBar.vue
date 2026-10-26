<script setup>
import { onBeforeRouteLeave } from 'vue-router';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  isDirty: {
    type: Boolean,
    default: false,
  },
  isSaving: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['save', 'discard']);

const { t } = useI18n();

onBeforeRouteLeave(() => {
  if (!props.isDirty) return true;
  // eslint-disable-next-line no-alert
  return window.confirm(t('CAPTAIN.ASSISTANTS.SETTINGS.SAVE_BAR.LEAVE'));
});
</script>

<template>
  <Transition
    enter-from-class="translate-y-2 opacity-0"
    leave-to-class="translate-y-2 opacity-0"
    enter-active-class="transition duration-150"
    leave-active-class="transition duration-150"
  >
    <div
      v-if="isDirty"
      class="sticky z-10 flex flex-wrap items-center justify-between gap-3 px-4 py-3 bottom-4 rounded-xl bg-n-solid-1 outline outline-1 outline-n-weak shadow-lg"
      role="region"
      :aria-label="t('CAPTAIN.ASSISTANTS.SETTINGS.SAVE_BAR.UNSAVED')"
    >
      <span class="flex items-center gap-2 text-sm text-n-slate-12">
        <span class="rounded-full size-2 bg-n-amber-9" aria-hidden="true" />
        {{ t('CAPTAIN.ASSISTANTS.SETTINGS.SAVE_BAR.UNSAVED') }}
      </span>
      <div class="flex items-center gap-2">
        <Button
          type="button"
          :label="t('CAPTAIN.ASSISTANTS.SETTINGS.SAVE_BAR.DISCARD')"
          variant="ghost"
          color="slate"
          size="sm"
          :disabled="isSaving"
          @click="emit('discard')"
        />
        <Button
          type="button"
          :label="t('CAPTAIN.ASSISTANTS.SETTINGS.SAVE')"
          size="sm"
          :is-loading="isSaving"
          @click="emit('save')"
        />
      </div>
    </div>
  </Transition>
</template>

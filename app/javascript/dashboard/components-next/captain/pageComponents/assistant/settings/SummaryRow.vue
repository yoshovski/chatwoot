<script setup>
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

// A setting shown as its current value with an explicit Edit action. The editor opens in a
// side panel, so the page stays a short, scannable list of decisions.
defineProps({
  icon: { type: String, default: '' },
  title: { type: String, required: true },
  summary: { type: String, default: '' },
  muted: { type: Boolean, default: false },
  actionLabel: { type: String, default: '' },
});

const emit = defineEmits(['edit']);
const { t } = useI18n();
</script>

<template>
  <div class="flex items-center gap-3 py-3.5">
    <span
      v-if="icon"
      class="flex items-center justify-center rounded-lg size-8 shrink-0 bg-n-alpha-2 text-n-slate-11"
      aria-hidden="true"
    >
      <span :class="icon" class="size-4" />
    </span>
    <div class="flex flex-col flex-1 min-w-0 gap-0.5">
      <span class="text-sm font-medium text-n-slate-12">{{ title }}</span>
      <span
        class="text-sm truncate"
        :class="muted ? 'text-n-slate-10' : 'text-n-slate-11'"
      >
        <slot name="summary">{{ summary }}</slot>
      </span>
    </div>
    <slot name="action">
      <Button
        type="button"
        :label="actionLabel || t('CAPTAIN.AGENT_UX.EDIT')"
        size="sm"
        variant="faded"
        color="slate"
        class="shrink-0"
        @click="emit('edit')"
      />
    </slot>
  </div>
</template>

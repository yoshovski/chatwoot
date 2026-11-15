<script setup>
import { ref, useId } from 'vue';
import { useI18n } from 'vue-i18n';

// Settings most shops never touch, folded under one "More options" line at the end of a step.
const props = defineProps({
  open: { type: Boolean, default: false },
});

const { t } = useI18n();
const isOpen = ref(props.open);
const id = useId();
</script>

<template>
  <div class="flex flex-col border-t border-n-weak pt-3">
    <button
      type="button"
      class="flex items-center gap-1.5 self-start text-sm font-medium text-n-slate-11 hover:text-n-slate-12"
      :aria-expanded="isOpen"
      :aria-controls="id"
      @click="isOpen = !isOpen"
    >
      <span
        class="i-lucide-chevron-right size-4 transition-transform"
        :class="{ 'rotate-90': isOpen }"
        aria-hidden="true"
      />
      {{ t('CAPTAIN.ASSISTANTS.SETTINGS.LEADS.SETUP.MORE_OPTIONS') }}
    </button>
    <div v-show="isOpen" :id="id" class="flex flex-col gap-4 pt-3">
      <slot />
    </div>
  </div>
</template>

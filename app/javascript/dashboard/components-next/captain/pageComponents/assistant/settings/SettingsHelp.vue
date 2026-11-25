<script setup>
import { ref, useId } from 'vue';
import { Tooltip } from 'floating-vue';

defineProps({
  label: { type: String, required: true },
  text: { type: String, required: true },
  note: { type: String, default: '' },
});
const tip = ref(null);
const descriptionId = useId();
</script>

<template>
  <Tooltip
    ref="tip"
    placement="top"
    :triggers="[]"
    :delay="{ show: 100, hide: 80 }"
    auto-hide
    no-auto-focus
  >
    <button
      type="button"
      class="grid size-7 shrink-0 place-items-center rounded-full text-n-slate-10 hover:bg-n-slate-3 hover:text-n-slate-12 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
      :aria-label="$t('CAPTAIN.ASSISTANTS.SETTINGS.HELP_ABOUT', { label })"
      :aria-describedby="descriptionId"
      @pointerenter="$event.pointerType === 'mouse' && tip.show()"
      @pointerleave="!$event.currentTarget.matches(':focus') && tip.hide()"
      @focus="tip.show()"
      @blur="tip.hide()"
      @click="tip.show()"
      @keydown.esc.stop="tip.hide()"
    >
      <span class="i-lucide-info size-4" aria-hidden="true" />
    </button>
    <template #popper>
      <div
        class="max-w-64 text-start text-xs leading-5"
        @mouseenter="tip.show()"
        @mouseleave="tip.hide()"
      >
        {{ text }} <span v-if="note">{{ note }}</span>
      </div>
    </template>
  </Tooltip>
  <span :id="descriptionId" class="sr-only">{{ text }} {{ note }}</span>
</template>

<script setup>
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';

defineProps({
  header: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    default: '',
  },
  inset: { type: Boolean, default: false },
  compact: {
    type: Boolean,
    default: false,
  },
  hideToggle: {
    type: Boolean,
    default: false,
  },
});

const modelValue = defineModel({ type: Boolean, default: false });
</script>

<template>
  <div
    class="flex flex-col items-start [interpolate-size:allow-keywords]"
    :class="{
      'rounded-xl outline outline-1 -outline-offset-1 outline-n-weak': !inset,
    }"
  >
    <div
      class="flex w-full flex-col items-start gap-1"
      :class="inset ? 'py-1.5' : 'py-3'"
    >
      <div
        class="flex w-full items-center justify-between gap-3"
        :class="{ 'px-4': !inset }"
      >
        <span class="text-heading-3 text-n-slate-12">
          {{ header }}
        </span>
        <template v-if="hideToggle">
          <slot name="hiddenToggle">
            <div class="size-2" />
          </slot>
        </template>
        <ToggleSwitch v-else v-model="modelValue" :aria-label="header" />
      </div>
      <span
        v-if="description"
        class="text-body-main text-n-slate-11"
        :class="{ 'px-4': !inset }"
      >
        {{ description }}
      </span>
      <slot />
    </div>
    <div
      v-if="$slots.editor"
      class="w-full border-t border-n-weak"
      :class="{
        'p-0': compact,
        'px-4 pb-4 pt-2': !compact && !inset,
        'pt-3': !compact && inset,
      }"
    >
      <slot name="editor" />
    </div>
  </div>
</template>

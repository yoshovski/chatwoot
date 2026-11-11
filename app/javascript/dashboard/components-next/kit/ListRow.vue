<script setup>
import Button from 'dashboard/components-next/button/Button.vue';

// One row of a list: a coloured dot, a title, one hint line and at most one action (or a short meta text).
defineProps({
  title: { type: String, required: true },
  hint: { type: String, default: '' },
  tone: {
    type: String,
    default: 'slate',
    validator: value =>
      ['blue', 'teal', 'amber', 'ruby', 'slate'].includes(value),
  },
  // Short text on the right when the row has no action, such as "Installed".
  meta: { type: String, default: '' },
  actionLabel: { type: String, default: '' },
  primary: { type: Boolean, default: false },
});

const emit = defineEmits(['action']);

const DOTS = {
  blue: 'bg-n-blue-9',
  teal: 'bg-n-teal-9',
  amber: 'bg-n-amber-9',
  ruby: 'bg-n-ruby-9',
  slate: 'bg-n-slate-8',
};
</script>

<template>
  <li class="flex items-center gap-3 py-3 first:pt-0 last:pb-0">
    <span class="size-2 shrink-0 rounded-full" :class="DOTS[tone]" />
    <div class="me-auto flex min-w-0 flex-col">
      <span class="truncate text-sm font-medium text-n-slate-12">
        {{ title }}
      </span>
      <span v-if="hint" class="truncate text-xs text-n-slate-11">
        {{ hint }}
      </span>
    </div>
    <Button
      v-if="actionLabel"
      :label="actionLabel"
      class="shrink-0"
      size="sm"
      v-bind="primary ? {} : { variant: 'faded', color: 'slate' }"
      @click="emit('action')"
    />
    <span v-else-if="meta" class="shrink-0 text-xs text-n-slate-11">
      {{ meta }}
    </span>
  </li>
</template>

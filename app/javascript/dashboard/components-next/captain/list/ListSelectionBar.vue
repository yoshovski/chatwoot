<script setup>
import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  count: { type: Number, required: true },
  busy: { type: Boolean, default: false },
});
const emit = defineEmits(['enable', 'disable', 'delete', 'clear']);
</script>

<!-- Floats at the bottom of the list while rows are selected, close to where the user clicked. -->
<template>
  <transition
    enter-active-class="transition duration-200 ease-out"
    enter-from-class="translate-y-3 opacity-0"
    leave-active-class="transition duration-150 ease-in"
    leave-to-class="translate-y-3 opacity-0"
  >
    <div
      v-if="count > 0"
      class="sticky bottom-4 z-20 flex justify-center pointer-events-none"
    >
      <div
        role="toolbar"
        :aria-label="$t('KNOWLEDGE_LIST.BULK_ACTIONS')"
        class="flex flex-wrap items-center gap-1 py-1.5 ps-4 pe-1.5 rounded-xl shadow-lg pointer-events-auto bg-n-slate-12 text-n-slate-1"
      >
        <span class="me-2 text-sm font-medium tabular-nums">
          {{ $t('KNOWLEDGE_LIST.SELECTED', { count }) }}
        </span>
        <div
          role="group"
          :aria-label="$t('KNOWLEDGE_LIST.USE_IN_ANSWERS')"
          class="flex items-center p-0.5 rounded-lg bg-n-slate-11/40"
        >
          <button
            type="button"
            class="flex items-center gap-1.5 px-2.5 py-1 text-sm font-medium rounded-md hover:bg-n-slate-1/15 disabled:opacity-50"
            :disabled="busy"
            @click="emit('enable')"
          >
            <span class="rounded-full size-2 bg-n-teal-9" aria-hidden="true" />
            {{ $t('KNOWLEDGE_LIST.TURN_ON') }}
          </button>
          <button
            type="button"
            class="flex items-center gap-1.5 px-2.5 py-1 text-sm font-medium rounded-md hover:bg-n-slate-1/15 disabled:opacity-50"
            :disabled="busy"
            @click="emit('disable')"
          >
            <span
              class="border rounded-full size-2 border-n-slate-6"
              aria-hidden="true"
            />
            {{ $t('KNOWLEDGE_LIST.TURN_OFF') }}
          </button>
        </div>
        <slot />
        <Button
          :label="$t('KNOWLEDGE_LIST.DELETE')"
          icon="i-lucide-trash"
          size="sm"
          variant="ghost"
          color="ruby"
          class="!text-n-ruby-6 hover:!bg-n-ruby-9/30"
          :disabled="busy"
          @click="emit('delete')"
        />
        <div class="w-px h-4 mx-1 bg-n-slate-10" />
        <Button
          v-tooltip.top="$t('KNOWLEDGE_LIST.CLEAR')"
          :aria-label="$t('KNOWLEDGE_LIST.CLEAR')"
          icon="i-lucide-x"
          size="sm"
          variant="ghost"
          color="slate"
          class="!text-n-slate-1 hover:!bg-n-slate-1/15"
          @click="emit('clear')"
        />
      </div>
    </div>
  </transition>
</template>

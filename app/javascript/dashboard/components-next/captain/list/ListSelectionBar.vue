<script setup>
import { computed } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

const props = defineProps({
  // The object returned by useListSelection.
  selection: { type: Object, required: true },
  total: { type: Number, required: true },
  busy: { type: Boolean, default: false },
});
const emit = defineEmits(['enable', 'disable', 'delete']);

const count = computed(() => props.selection.count.value);
const enabledState = computed(() => props.selection.enabledState.value);

// On only when every selected item is used; flipping sets them all the same way.
const useInAnswers = computed({
  get: () => enabledState.value === 'on',
  set: enabled => {
    if (enabled) emit('enable');
    else emit('disable');
  },
});
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
        class="flex flex-wrap items-center gap-1 py-1.5 ps-4 pe-1.5 border rounded-xl shadow-lg pointer-events-auto bg-n-solid-1 border-n-weak text-n-slate-12 dark:bg-n-solid-3 dark:border-n-strong"
      >
        <span class="text-sm font-medium tabular-nums">
          {{
            selection.allMatching.value
              ? $t('KNOWLEDGE_LIST.ALL_SELECTED', { count })
              : $t('KNOWLEDGE_LIST.SELECTED', { count })
          }}
        </span>
        <Button
          v-if="selection.canSelectMatching.value"
          :label="$t('KNOWLEDGE_LIST.SELECT_MATCHING', { count: total })"
          size="sm"
          variant="link"
          class="ms-1"
          @click="selection.selectMatching()"
        />
        <div class="w-px h-4 mx-2 bg-n-weak" />
        <label
          v-tooltip.top="$t('KNOWLEDGE_LIST.USE_IN_ANSWERS_HINT')"
          class="flex items-center gap-2 px-2 py-1 text-sm rounded-lg cursor-pointer hover:bg-n-alpha-2"
          :class="{ 'opacity-50 pointer-events-none': busy }"
        >
          <Switch
            v-model="useInAnswers"
            :aria-label="$t('KNOWLEDGE_LIST.USE_IN_ANSWERS')"
          />
          <span>{{ $t('KNOWLEDGE_LIST.USE_IN_ANSWERS') }}</span>
          <span v-if="enabledState === 'mixed'" class="text-xs text-n-slate-11">
            {{ $t('KNOWLEDGE_LIST.SOME_OFF') }}
          </span>
        </label>
        <slot />
        <Button
          :label="$t('KNOWLEDGE_LIST.DELETE')"
          icon="i-lucide-trash"
          size="sm"
          variant="ghost"
          color="ruby"
          :disabled="busy"
          @click="emit('delete')"
        />
        <div class="w-px h-4 mx-1 bg-n-weak" />
        <Button
          v-tooltip.top="$t('KNOWLEDGE_LIST.CLEAR')"
          :aria-label="$t('KNOWLEDGE_LIST.CLEAR')"
          icon="i-lucide-x"
          size="sm"
          variant="ghost"
          color="slate"
          @click="selection.clear()"
        />
      </div>
    </div>
  </transition>
</template>

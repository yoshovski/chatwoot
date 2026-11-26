<script setup>
import { ref } from 'vue';
import { useToggle } from '@vueuse/core';
import { vOnClickOutside } from '@vueuse/components';
import DropdownFloating from './DropdownFloating.vue';
import { provideDropdownContext, useDropdownTeleport } from './provider.js';

defineProps({
  floating: Boolean,
  align: { type: String, default: 'start' },
});
const emit = defineEmits(['close']);
const [isOpen, toggle] = useToggle(false);

const teleport = useDropdownTeleport();
const containerRef = ref(null);

// A getter, not a computed: consumers swap the trigger element as their state changes — a multi
// select trades its placeholder for a chips button once something is picked.
const getTrigger = () => containerRef.value?.firstElementChild ?? null;

const closeMenu = () => {
  if (isOpen.value) {
    emit('close');
    toggle(false);
  }
};

const closeFromKeyboard = () => {
  closeMenu();
  getTrigger()?.focus();
};

// A teleported menu sits outside the container, so clicks inside it read as clicks outside.
const clickOutsideHandler = [closeMenu, { ignore: ['[data-dropdown-menu]'] }];

provideDropdownContext({
  isOpen,
  toggle,
  closeMenu,
});
</script>

<template>
  <div
    ref="containerRef"
    v-on-click-outside="clickOutsideHandler"
    class="relative space-y-2"
    @keydown.esc="isOpen && closeFromKeyboard()"
  >
    <slot name="trigger" :is-open :toggle="() => toggle()" />
    <template v-if="isOpen">
      <DropdownFloating
        v-if="floating || teleport"
        :trigger="getTrigger"
        :align="align"
        @escape="closeFromKeyboard"
      >
        <slot :close="closeMenu" />
      </DropdownFloating>
      <div v-else class="absolute">
        <slot :close="closeMenu" />
      </div>
    </template>
  </div>
</template>

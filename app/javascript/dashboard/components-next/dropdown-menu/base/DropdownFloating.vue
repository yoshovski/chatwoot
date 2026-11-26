<script setup>
import { nextTick, onMounted, ref } from 'vue';
import { useDropdownPosition } from 'dashboard/composables/useDropdownPosition';
import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';

const { trigger, align } = defineProps({
  align: { type: String, default: 'start' },
  trigger: {
    type: Function,
    required: true,
  },
});

defineEmits(['escape']);

const menuRef = ref(null);

const { fixedPosition } = useDropdownPosition(trigger, menuRef, true, {
  align,
});
onMounted(async () => {
  if (!trigger()?.matches(':focus-visible')) return;
  await nextTick();
  menuRef.value?.querySelector('button:not(:disabled), a[href]')?.focus();
});
</script>

<template>
  <TeleportWithDirection to="body">
    <div
      data-dropdown-menu
      class="overflow-y-auto"
      :class="fixedPosition.class"
      :style="fixedPosition.style"
      @keydown.esc.stop="$emit('escape')"
    >
      <div ref="menuRef" class="[&>*]:!static">
        <slot />
      </div>
    </div>
  </TeleportWithDirection>
</template>

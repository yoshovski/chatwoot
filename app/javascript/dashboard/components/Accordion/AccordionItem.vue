<script setup>
import EmojiOrIcon from 'shared/components/EmojiOrIcon.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  title: {
    type: String,
    required: true,
  },
  compact: {
    type: Boolean,
    default: false,
  },
  icon: {
    type: String,
    default: '',
  },
  emoji: {
    type: String,
    default: '',
  },
  isOpen: {
    type: Boolean,
    default: true,
  },
  // Design step (T30): the section as a kit card that can be dragged by its header.
  card: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['toggle']);

const onToggle = () => {
  emit('toggle');
};
</script>

<template>
  <section
    v-if="card"
    class="group rounded-card bg-n-solid-2 text-sm shadow-card outline outline-1 -outline-offset-1 outline-n-container"
  >
    <button
      type="button"
      class="drag-handle relative flex w-full cursor-grab select-none items-center gap-2 px-5 py-3.5 text-start"
      :aria-expanded="isOpen"
      @click.stop="onToggle"
    >
      <Icon
        icon="i-lucide-grip-vertical"
        class="absolute start-1 size-3.5 text-n-slate-9 opacity-0 transition-opacity group-hover:opacity-100"
      />
      <h3 class="mb-0 flex-1 truncate text-sm font-semibold text-n-slate-12">
        {{ title }}
      </h3>
      <slot name="button" />
      <Icon
        icon="i-lucide-chevron-down"
        class="size-4 shrink-0 text-n-slate-10 transition-transform"
        :class="{ 'rotate-180': isOpen }"
      />
    </button>
    <div v-if="isOpen" class="px-5 pb-5">
      <slot />
    </div>
  </section>
  <div v-else class="text-sm">
    <button
      class="flex items-center select-none w-full rounded-lg bg-n-slate-2 outline outline-1 outline-n-weak m-0 cursor-grab justify-between py-2 px-4 drag-handle"
      :class="{ 'rounded-bl-none rounded-br-none': isOpen }"
      @click.stop="onToggle"
    >
      <div class="flex justify-between">
        <EmojiOrIcon class="inline-block w-5" :icon="icon" :emoji="emoji" />
        <h5 class="text-n-slate-12 text-sm mb-0 py-0 pr-2 pl-0">
          {{ title }}
        </h5>
      </div>
      <div class="flex flex-row">
        <slot name="button" />
        <div class="flex justify-end w-3 text-n-blue-11 cursor-pointer">
          <fluent-icon v-if="isOpen" size="24" icon="subtract" type="solid" />
          <fluent-icon v-else size="24" icon="add" type="solid" />
        </div>
      </div>
    </button>
    <div
      v-if="isOpen"
      class="outline outline-1 outline-n-weak -mt-[-1px] border-t-0 rounded-br-lg rounded-bl-lg"
      :class="compact ? 'p-0' : 'px-2 py-4'"
    >
      <slot />
    </div>
  </div>
</template>

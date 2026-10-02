<script setup>
import { computed } from 'vue';
import Draggable from 'vuedraggable';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  addLabel: { type: String, required: true },
  emptyLabel: { type: String, required: true },
  placeholder: { type: String, required: true },
  reorderLabel: { type: String, required: true },
  deleteLabel: { type: String, required: true },
  maxItems: { type: Number, default: 10 },
});

const items = defineModel({ type: Array, default: () => [] });

const canAddItem = computed(() => items.value.length < props.maxItems);

const addItem = () => {
  if (!canAddItem.value) return;

  items.value.push({
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    title: '',
    enabled: true,
  });
};

const removeItem = index => {
  items.value.splice(index, 1);
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <p
      v-if="!items.length"
      class="m-0 rounded-xl bg-n-alpha-black2 px-4 py-3 text-sm text-n-slate-11"
    >
      {{ emptyLabel }}
    </p>
    <Draggable
      v-else
      v-model="items"
      item-key="id"
      handle=".drag-handle"
      class="flex flex-col gap-2"
    >
      <template #item="{ element, index }">
        <div
          class="flex items-center gap-3 rounded-xl bg-n-alpha-black2 px-3 py-2"
        >
          <button
            type="button"
            class="drag-handle cursor-grab border-0 bg-transparent p-1 text-n-slate-10 active:cursor-grabbing"
            :aria-label="reorderLabel"
          >
            <Icon icon="i-woot-drag-indicator" class="size-4" />
          </button>
          <Switch v-model="element.enabled" />
          <input
            v-model.trim="element.title"
            type="text"
            maxlength="120"
            :placeholder="placeholder"
            class="!mb-0 min-w-0 flex-1 rounded-lg border-0 bg-n-background px-3 py-2 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
          />
          <Button
            type="button"
            size="sm"
            color="slate"
            variant="ghost"
            icon="i-lucide-trash-2"
            :aria-label="deleteLabel"
            @click="removeItem(index)"
          />
        </div>
      </template>
    </Draggable>
    <Button
      type="button"
      color="slate"
      variant="outline"
      icon="i-lucide-plus"
      :label="addLabel"
      class="self-start"
      :disabled="!canAddItem"
      @click="addItem"
    />
  </div>
</template>

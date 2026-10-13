<script setup>
import { computed } from 'vue';
import Draggable from 'vuedraggable';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SelectInput from 'dashboard/components-next/select/Select.vue';

const props = defineProps({
  addLabel: { type: String, required: true },
  emptyLabel: { type: String, required: true },
  placeholder: { type: String, required: true },
  reorderLabel: { type: String, required: true },
  deleteLabel: { type: String, required: true },
  maxItems: { type: Number, default: 10 },
  allowActions: { type: Boolean, default: false },
  actionOptions: { type: Array, default: () => [] },
  urlPlaceholder: { type: String, default: '' },
  cannedPlaceholder: { type: String, default: '' },
});

const items = defineModel({ type: Array, default: () => [] });

const canAddItem = computed(() => items.value.length < props.maxItems);

const addItem = () => {
  if (!canAddItem.value) return;

  const newItem = {
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    title: '',
    enabled: true,
  };

  if (props.allowActions) {
    newItem.action_type = 'message';
    newItem.target = '';
  }

  items.value.push(newItem);
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
          class="flex flex-col gap-2 rounded-xl bg-n-alpha-black2"
          :class="allowActions ? 'p-3' : 'px-3 py-2'"
        >
          <div class="flex items-center gap-3">
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
            <SelectInput
              v-if="allowActions"
              :model-value="element.action_type || 'message'"
              :options="actionOptions"
              class="!w-48 shrink-0"
              @update:model-value="element.action_type = $event"
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
          <div
            v-if="allowActions && element.action_type === 'url'"
            class="ms-11 me-9"
          >
            <input
              v-model.trim="element.target"
              type="url"
              :placeholder="urlPlaceholder"
              class="!mb-0 w-full rounded-lg border-0 bg-n-background px-3 py-2 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
            />
          </div>
          <div
            v-else-if="allowActions && element.action_type === 'canned'"
            class="ms-11 me-9"
          >
            <textarea
              v-model="element.target"
              rows="2"
              :placeholder="cannedPlaceholder"
              class="!mb-0 w-full rounded-lg border-0 bg-n-background px-3 py-2 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
            />
          </div>
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

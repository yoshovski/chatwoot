<script setup>
import { computed } from 'vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  allItems: {
    type: Array,
    required: true,
  },
  selectAllLabel: {
    type: String,
    default: '',
  },
  selectedCountLabel: {
    type: String,
    default: '',
  },
  deleteLabel: {
    type: String,
    default: 'Delete',
  },
  // Shows only the selected count, icon-only delete and a clear button.
  compact: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['bulkDelete']);

const modelValue = defineModel({
  type: Set,
  default: () => new Set(),
});

const selectedCount = computed(() => modelValue.value.size);
const visibleItemIds = computed(() => props.allItems.map(item => item.id));
const visibleItemCount = computed(() => visibleItemIds.value.length);
const selectedVisibleCount = computed(
  () => visibleItemIds.value.filter(id => modelValue.value.has(id)).length
);
const hasSelected = computed(() => selectedCount.value > 0);
const isIndeterminate = computed(
  () =>
    selectedVisibleCount.value > 0 &&
    selectedVisibleCount.value < visibleItemCount.value
);
const allSelected = computed(
  () =>
    visibleItemCount.value > 0 &&
    selectedVisibleCount.value === visibleItemCount.value
);

const bulkCheckboxState = computed({
  get: () => allSelected.value,
  set: shouldSelectAll => {
    if (!visibleItemCount.value) {
      return;
    }

    const updatedSelection = new Set(modelValue.value);
    if (shouldSelectAll) {
      visibleItemIds.value.forEach(id => updatedSelection.add(id));
    } else {
      visibleItemIds.value.forEach(id => updatedSelection.delete(id));
    }
    modelValue.value = updatedSelection;
  },
});
</script>

<template>
  <transition
    name="slide-fade"
    enter-active-class="transition-all duration-300 ease-out"
    enter-from-class="opacity-0 transform ltr:-translate-x-4 rtl:translate-x-4"
    enter-to-class="opacity-100 transform translate-x-0"
    leave-active-class="hidden opacity-0"
  >
    <div
      v-if="hasSelected && compact"
      class="flex items-center gap-1 py-1 ps-3 pe-1 rounded-lg bg-n-solid-2 outline outline-1 outline-n-container shadow"
    >
      <Checkbox
        v-model="bulkCheckboxState"
        v-tooltip.top="selectAllLabel"
        :indeterminate="isIndeterminate"
        :aria-label="selectAllLabel"
      />
      <span
        class="ms-1.5 me-2 text-sm font-medium text-n-slate-12 tabular-nums whitespace-nowrap"
      >
        {{ selectedCountLabel }}
      </span>
      <div class="h-4 w-px bg-n-strong" />
      <slot name="secondaryActions" />
      <slot name="actions" :selected-count="selectedCount">
        <Button
          v-tooltip.top="deleteLabel"
          :aria-label="deleteLabel"
          sm
          ruby
          ghost
          icon="i-lucide-trash"
          @click="emit('bulkDelete')"
        />
      </slot>
      <div class="h-4 w-px bg-n-strong" />
      <Button
        v-tooltip.top="$t('CAPTAIN.BULK_SELECT.CLEAR')"
        :aria-label="$t('CAPTAIN.BULK_SELECT.CLEAR')"
        sm
        slate
        ghost
        icon="i-lucide-x"
        @click="modelValue = new Set()"
      />
    </div>
    <div
      v-else-if="hasSelected"
      class="flex items-center gap-3 py-1 ltr:pl-3 rtl:pr-3 ltr:pr-4 rtl:pl-4 rounded-lg bg-n-solid-2 outline outline-1 outline-n-container shadow"
    >
      <div class="flex items-center gap-3 min-w-0">
        <div class="flex items-center gap-1.5 min-w-0">
          <Checkbox
            v-model="bulkCheckboxState"
            :indeterminate="isIndeterminate"
          />
          <span
            class="text-sm font-medium truncate text-n-slate-12 tabular-nums"
          >
            {{ selectAllLabel }}
          </span>
        </div>
        <span class="text-sm text-n-slate-10 truncate tabular-nums">
          {{ selectedCountLabel }}
        </span>
        <div v-if="$slots.primaryActions" class="h-4 w-px bg-n-strong" />
        <slot v-if="$slots.primaryActions" name="primaryActions" />
      </div>
      <div class="flex items-center gap-3">
        <slot v-if="$slots.secondaryActions" name="secondaryActions" />
        <div v-if="$slots.secondaryActions" class="h-4 w-px bg-n-strong" />
        <div class="flex items-center gap-3">
          <slot name="actions" :selected-count="selectedCount">
            <Button
              :label="deleteLabel"
              sm
              ruby
              ghost
              class="!px-1.5"
              icon="i-lucide-trash"
              @click="emit('bulkDelete')"
            />
          </slot>
        </div>
      </div>
    </div>
    <div v-else class="flex items-center gap-3">
      <slot name="default-actions" />
    </div>
  </transition>
</template>

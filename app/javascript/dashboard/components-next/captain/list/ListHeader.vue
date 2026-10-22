<script setup>
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

defineProps({
  selection: { type: Object, required: true },
  total: { type: Number, required: true },
  pageCount: { type: Number, required: true },
  // Shown next to the checkbox, e.g. "433 matching sources".
  label: { type: String, required: true },
  selectable: { type: Boolean, default: true },
});
</script>

<template>
  <div>
    <div
      class="flex items-center gap-3 px-4 py-2.5 text-xs font-medium border-b border-n-weak text-n-slate-11 bg-n-alpha-1"
    >
      <Checkbox
        v-if="selectable"
        :model-value="selection.pageSelected.value"
        :indeterminate="selection.pageIndeterminate.value"
        :aria-label="$t('KNOWLEDGE_LIST.SELECT_PAGE')"
        @update:model-value="selection.togglePage()"
      />
      <span class="flex-1 min-w-0 truncate tabular-nums">{{ label }}</span>
      <slot />
    </div>
    <div
      v-if="selection.canSelectMatching.value || selection.allMatching.value"
      class="flex flex-wrap items-center justify-center gap-1 px-4 py-2 text-sm border-b border-n-weak bg-n-brand/5 text-n-slate-12"
    >
      <template v-if="selection.allMatching.value">
        {{ $t('KNOWLEDGE_LIST.ALL_MATCHING_SELECTED', { count: total }) }}
        <button
          type="button"
          class="font-medium text-n-brand hover:underline"
          @click="selection.clear()"
        >
          {{ $t('KNOWLEDGE_LIST.CLEAR') }}
        </button>
      </template>
      <template v-else>
        {{ $t('KNOWLEDGE_LIST.PAGE_SELECTED', { count: pageCount }) }}
        <button
          type="button"
          class="font-medium text-n-brand hover:underline"
          @click="selection.selectMatching()"
        >
          {{ $t('KNOWLEDGE_LIST.SELECT_MATCHING', { count: total }) }}
        </button>
      </template>
    </div>
  </div>
</template>

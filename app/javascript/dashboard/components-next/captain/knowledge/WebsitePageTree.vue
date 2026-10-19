<script setup>
import { computed, ref } from 'vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  node: { type: Object, required: true },
  selected: { type: Array, required: true },
});
const emit = defineEmits(['toggle', 'preview']);
const expanded = ref(false);
const selectedCount = computed(
  () => props.node.pages.filter(url => props.selected.includes(url)).length
);
const checked = computed(
  () =>
    props.node.pages.length > 0 &&
    selectedCount.value === props.node.pages.length
);
const toggle = value =>
  emit('toggle', { urls: props.node.pages, selected: value });
</script>

<template>
  <div class="min-w-0">
    <div class="flex items-center gap-2 rounded-md py-1 hover:bg-n-alpha-1">
      <Checkbox
        :model-value="checked"
        :indeterminate="selectedCount > 0 && !checked"
        :disabled="!node.pages.length"
        :aria-label="node.label"
        @update:model-value="toggle"
      />
      <Button
        v-if="node.children.length"
        :icon="expanded ? 'i-lucide-chevron-down' : 'i-lucide-chevron-right'"
        :aria-label="$t('CAPTAIN.WEBSITES.EXPAND', { name: node.label })"
        :aria-expanded="expanded"
        variant="ghost"
        color="slate"
        size="xs"
        @click="expanded = !expanded"
      />
      <button
        type="button"
        class="min-w-0 flex-1 truncate text-start text-sm text-n-slate-12"
        :title="node.page?.url || node.label"
        @click="
          node.children.length
            ? (expanded = !expanded)
            : emit('preview', node.page)
        "
      >
        {{ node.label }}
      </button>
      <span v-if="node.page?.blocked_reason" class="text-xs text-n-slate-11">
        {{ $t(`CAPTAIN.WEBSITES.BLOCKED.${node.page.blocked_reason}`) }}
      </span>
      <span v-else-if="node.page?.document_id" class="text-xs text-n-slate-11">
        {{
          $t(
            `CAPTAIN.WEBSITES.PAGE_STATUS.${node.page.knowledge_state || node.page.sync_status || 'syncing'}`
          )
        }}
      </span>
      <span v-else-if="node.children.length" class="text-xs text-n-slate-11">
        {{ selectedCount }}/{{ node.pages.length }}
      </span>
    </div>
    <div v-if="expanded" class="ms-2 border-s border-n-weak ps-3">
      <div v-if="node.page" class="flex items-center gap-2 py-1">
        <Checkbox
          :model-value="selected.includes(node.page.url)"
          :disabled="!!node.page.blocked_reason"
          :aria-label="node.page.url"
          @update:model-value="
            value => emit('toggle', { urls: [node.page.url], selected: value })
          "
        />
        <button
          type="button"
          class="truncate text-start text-sm text-n-blue-11"
          @click="emit('preview', node.page)"
        >
          {{ node.page.title || $t('CAPTAIN.WEBSITES.THIS_PAGE') }}
        </button>
      </div>
      <WebsitePageTree
        v-for="child in node.children"
        :key="child.key"
        :node="child"
        :selected="selected"
        @toggle="emit('toggle', $event)"
        @preview="emit('preview', $event)"
      />
    </div>
  </div>
</template>

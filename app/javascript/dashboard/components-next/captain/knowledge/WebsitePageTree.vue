<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  node: { type: Object, required: true },
  selected: { type: Array, required: true },
  // Section labels from discovery, keyed by section.
  sectionLabels: { type: Object, default: () => ({}) },
});
const emit = defineEmits(['toggle', 'preview']);
const { t } = useI18n();
const expanded = ref(false);
const selectedCount = computed(
  () => props.node.pages.filter(url => props.selected.includes(url)).length
);
const checked = computed(
  () =>
    props.node.pages.length > 0 &&
    selectedCount.value === props.node.pages.length
);
const sectionLabel = computed(() =>
  props.node.section ? props.sectionLabels[props.node.section] : null
);
const page = computed(() => props.node.page);
const label = computed(
  () => props.node.label || t('CAPTAIN.WEBSITES.HOME_SECTION')
);
// Pages listed by a sitemap or link but never opened have no word count yet.
const pageReason = computed(() => {
  if (!page.value) return null;
  if (page.value.blocked_reason || page.value.reason) {
    return page.value.blocked_reason || page.value.reason;
  }
  return page.value.words === undefined && !page.value.checked
    ? 'unchecked'
    : null;
});
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
        :aria-label="label"
        @update:model-value="toggle"
      />
      <Button
        v-if="node.children.length"
        :icon="expanded ? 'i-lucide-chevron-down' : 'i-lucide-chevron-right'"
        :aria-label="$t('CAPTAIN.WEBSITES.EXPAND', { name: label })"
        :aria-expanded="expanded"
        variant="ghost"
        color="slate"
        size="xs"
        @click="expanded = !expanded"
      />
      <button
        type="button"
        class="flex min-w-0 flex-1 flex-col text-start"
        :title="page?.url || node.key"
        @click="page ? emit('preview', page) : (expanded = !expanded)"
      >
        <span class="truncate text-sm text-n-slate-12">
          {{ label }}
        </span>
        <span v-if="sectionLabel" class="truncate text-xs text-n-slate-11">
          {{
            $t('CAPTAIN.WEBSITES.SECTION_SUMMARY', {
              label: $t(
                `CAPTAIN.WEBSITES.SECTION_LABELS.${sectionLabel.label}`
              ),
              reason: sectionLabel.reason,
            })
          }}
        </span>
      </button>
      <span
        v-if="page?.new"
        class="shrink-0 rounded bg-n-teal-3 px-1.5 py-0.5 text-xs font-medium text-n-teal-11"
      >
        {{ $t('CAPTAIN.WEBSITES.NEW_PAGE') }}
      </span>
      <span v-if="page?.document_id" class="shrink-0 text-xs text-n-slate-11">
        {{
          $t(
            `CAPTAIN.WEBSITES.PAGE_STATUS.${page.knowledge_state || page.sync_status || 'syncing'}`
          )
        }}
      </span>
      <span
        v-else-if="pageReason"
        v-tooltip.top="
          pageReason === 'unchecked'
            ? $t('CAPTAIN.WEBSITES.UNCHECKED_HINT')
            : undefined
        "
        class="shrink-0 rounded bg-n-alpha-2 px-1.5 py-0.5 text-xs text-n-slate-11"
      >
        {{ $t(`CAPTAIN.WEBSITES.REASONS.${pageReason}`) }}
      </span>
      <span v-else-if="node.children.length" class="text-xs text-n-slate-11">
        {{ selectedCount }}/{{ node.pages.length }}
      </span>
    </div>
    <div v-if="expanded" class="ms-2 border-s border-n-weak ps-3">
      <WebsitePageTree
        v-for="child in node.children"
        :key="child.key"
        :node="child"
        :selected="selected"
        :section-labels="sectionLabels"
        @toggle="emit('toggle', $event)"
        @preview="emit('preview', $event)"
      />
    </div>
  </div>
</template>

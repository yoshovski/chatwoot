<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import ToolChip from './ToolChip.vue';
import TemplatePreviewChat from './TemplatePreviewChat.vue';

const props = defineProps({
  template: {
    type: Object,
    required: true,
  },
  tools: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['use']);

const { t } = useI18n();
const isHovered = ref(false);

const COLOR_GRADIENTS = {
  amber:
    'bg-gradient-to-br from-n-amber-3/80 to-n-amber-4/30 dark:from-n-amber-3/20 dark:to-n-amber-4/10',
  iris: 'bg-gradient-to-br from-n-iris-3/80 to-n-iris-4/30 dark:from-n-iris-3/20 dark:to-n-iris-4/10',
  teal: 'bg-gradient-to-br from-n-teal-3/80 to-n-teal-4/30 dark:from-n-teal-3/20 dark:to-n-teal-4/10',
  violet:
    'bg-gradient-to-br from-n-violet-3/80 to-n-violet-4/30 dark:from-n-violet-3/20 dark:to-n-violet-4/10',
  slate:
    'bg-gradient-to-br from-n-slate-3/80 to-n-slate-4/30 dark:from-n-slate-3/20 dark:to-n-slate-4/10',
};

const headerGradient = computed(() => {
  return COLOR_GRADIENTS[props.template.color] || COLOR_GRADIENTS.slate;
});

const isMissingRequiredTools = computed(() => {
  if (!props.template.requiredTools?.length) return false;
  const availableToolIds = new Set(
    (props.tools || []).map(tool => (typeof tool === 'string' ? tool : tool.id))
  );
  return props.template.requiredTools.some(
    toolId => !availableToolIds.has(toolId)
  );
});

const usedToolIds = computed(() => {
  const result = props.template.build({}, props.tools || []);
  const matches = result.instruction?.matchAll(/\(tool:\/\/([^)]+)\)/g) || [];
  return [...new Set([...matches].map(m => m[1]))];
});

const buttonTooltip = computed(() => {
  if (isMissingRequiredTools.value) {
    return t(
      'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.NEEDS_SHOPIFY_TOOLTIP',
      'This template requires the Find products tool, which is available when Shopify is connected.'
    );
  }
  return '';
});

const onUseTemplate = () => {
  if (isMissingRequiredTools.value) return;
  emit('use', props.template);
};
</script>

<template>
  <div
    class="flex flex-col rounded-2xl border border-n-weak bg-n-alpha-3 overflow-hidden shadow-sm hover:shadow-md transition-shadow duration-200"
    @mouseenter="isHovered = true"
    @mouseleave="isHovered = false"
  >
    <!-- Card Header -->
    <div
      class="p-5 flex flex-col gap-3 border-b border-n-weak"
      :class="headerGradient"
    >
      <div class="flex items-start justify-between gap-3">
        <span class="text-3xl leading-none select-none">
          {{ template.emoji }}
        </span>
        <span
          v-if="isMissingRequiredTools"
          v-tooltip.top="{
            content: buttonTooltip,
            delay: { show: 200, hide: 0 },
          }"
          class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-medium bg-n-amber-3 text-n-amber-11 border border-n-amber-4 select-none cursor-default"
        >
          {{
            t(
              'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.NEEDS_SHOPIFY',
              'Needs Shopify'
            )
          }}
        </span>
      </div>

      <div class="flex flex-col gap-1">
        <h3 class="text-base font-semibold text-n-slate-12 tracking-tight m-0">
          {{ template.title }}
        </h3>
        <p class="text-xs text-n-slate-11 line-clamp-2 leading-relaxed m-0">
          {{ template.tagline }}
        </p>
      </div>

      <!-- Tools Used Row -->
      <div
        v-if="usedToolIds.length"
        class="flex items-center gap-1 flex-wrap pt-1"
      >
        <ToolChip
          v-for="toolId in usedToolIds"
          :key="toolId"
          :tool-id="toolId"
        />
      </div>
    </div>

    <!-- Live Mini-Chat Preview -->
    <div class="p-4 flex flex-col gap-3 flex-1 justify-between">
      <TemplatePreviewChat :demo="template.demo" :is-playing="isHovered" />

      <div class="pt-2">
        <span
          v-tooltip.top="{
            content: buttonTooltip,
            delay: { show: 200, hide: 0 },
          }"
          class="block w-full"
        >
          <Button
            sm
            :disabled="isMissingRequiredTools"
            :label="
              t(
                'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.USE_TEMPLATE',
                'Use template'
              )
            "
            class="w-full justify-center"
            @click="onUseTemplate"
          />
        </span>
      </div>
    </div>
  </div>
</template>

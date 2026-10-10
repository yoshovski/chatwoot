<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import { getToolIdsFromInstruction } from './scenarioTools';
import {
  buildFromTemplate,
  countSteps,
  isTemplateAvailable,
} from './scenarioTemplates';

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

const MAX_VISIBLE_TOOLS = 3;

const ICON_COLORS = {
  amber: 'bg-n-amber-3 text-n-amber-11',
  iris: 'bg-n-iris-3 text-n-iris-11',
  teal: 'bg-n-teal-3 text-n-teal-11',
  ruby: 'bg-n-ruby-3 text-n-ruby-11',
  slate: 'bg-n-slate-3 text-n-slate-11',
};

const i18nKey = computed(
  () =>
    `CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.${props.template.id.toUpperCase()}`
);

const isAvailable = computed(() =>
  isTemplateAvailable(props.template, props.tools)
);

const defaultInstruction = computed(
  () => buildFromTemplate(props.template, {}, props.tools).instruction
);

const stepCount = computed(() => countSteps(defaultInstruction.value));

const usedTools = computed(() =>
  getToolIdsFromInstruction(defaultInstruction.value)
    .map(id => props.tools.find(tool => tool.id === id))
    .filter(Boolean)
);

const visibleTools = computed(() =>
  usedTools.value.slice(0, MAX_VISIBLE_TOOLS)
);
const hiddenToolCount = computed(
  () => usedTools.value.length - visibleTools.value.length
);
const toolsTooltip = computed(() =>
  usedTools.value.map(tool => tool.title).join(', ')
);

const onClick = () => {
  if (isAvailable.value) emit('use', props.template);
};
</script>

<template>
  <article
    v-tooltip.top="
      isAvailable
        ? null
        : t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.NEEDS_SHOPIFY_TOOLTIP')
    "
    class="group relative flex flex-col gap-3 h-full w-full p-4 text-start rounded-xl border border-n-strong bg-n-solid-2 transition-colors motion-reduce:transition-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
    :class="
      isAvailable
        ? 'hover:border-n-slate-7 hover:bg-n-solid-3'
        : 'cursor-not-allowed'
    "
    :data-test="`template-${template.id}`"
  >
    <div class="flex items-start justify-between w-full">
      <span
        class="flex items-center justify-center size-9 rounded-lg"
        :class="ICON_COLORS[template.color]"
      >
        <span class="size-5" :class="template.icon" />
      </span>
      <span
        v-if="isAvailable"
        class="i-lucide-arrow-up-right size-4 text-n-slate-10 opacity-0 group-hover:opacity-100 group-focus-visible:opacity-100 transition-opacity motion-reduce:transition-none"
      />
    </div>

    <div class="flex flex-col gap-1">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t(`${i18nKey}.TITLE`) }}
      </span>
      <span class="text-sm text-n-slate-11 line-clamp-2">
        {{ t(`${i18nKey}.TAGLINE`) }}
      </span>
    </div>

    <div
      class="mt-auto flex items-center justify-between w-full text-xs text-n-slate-10"
    >
      <span v-if="isAvailable">
        {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.STEPS', stepCount) }}
      </span>
      <span v-else class="inline-flex items-center gap-1 text-n-amber-11">
        <span class="i-lucide-plug size-3.5" />
        {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.NEEDS_SHOPIFY') }}
      </span>

      <span
        v-if="usedTools.length"
        v-tooltip.top="toolsTooltip"
        class="flex items-center"
      >
        <span
          v-for="tool in visibleTools"
          :key="tool.id"
          class="flex items-center justify-center size-6 -ms-1.5 first:ms-0 rounded-full bg-n-alpha-2 ring-2 ring-n-solid-2 text-xs"
        >
          {{ tool.emoji }}
        </span>
        <span
          v-if="hiddenToolCount"
          class="flex items-center justify-center size-6 -ms-1.5 rounded-full bg-n-alpha-2 ring-2 ring-n-solid-2 text-xs text-n-slate-11"
        >
          {{ `+${hiddenToolCount}` }}
        </span>
      </span>
    </div>
    <Button
      class="mt-2 w-full"
      :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.USE_TEMPLATE')"
      icon="i-lucide-plus"
      :disabled="!isAvailable"
      @click="onClick"
    />
  </article>
</template>

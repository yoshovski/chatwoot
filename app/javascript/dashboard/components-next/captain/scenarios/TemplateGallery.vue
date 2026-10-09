<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useUISettings } from 'dashboard/composables/useUISettings';
import Button from 'dashboard/components-next/button/Button.vue';
import TemplateCard from './TemplateCard.vue';
import { SCENARIO_TEMPLATES } from './scenarioTemplates';

defineProps({
  tools: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['useTemplate']);

const { t } = useI18n();
const { uiSettings, updateUISettings } = useUISettings();

const isExpanded = computed(() => {
  return uiSettings.value?.show_scenarios_suggestions !== false;
});

const toggleExpanded = () => {
  updateUISettings({ show_scenarios_suggestions: !isExpanded.value });
};

const onUseTemplate = template => {
  emit('useTemplate', template);
};
</script>

<template>
  <div class="flex flex-col gap-4 w-full">
    <!-- Header with Toggle Button -->
    <div class="flex items-center justify-between gap-4">
      <div class="flex flex-col gap-0.5">
        <h2
          class="text-sm font-semibold text-n-slate-12 m-0 flex items-center gap-2"
        >
          <span aria-hidden="true">{{ '✨' }}</span>
          <span>
            {{
              t(
                'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.GALLERY_TITLE',
                'Scenario templates'
              )
            }}
          </span>
        </h2>
        <p class="text-xs text-n-slate-11 m-0">
          {{
            t(
              'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.GALLERY_DESCRIPTION',
              'Start with ready-made workflows for quotes, calls, returns, product discovery, and B2B.'
            )
          }}
        </p>
      </div>

      <Button
        xs
        ghost
        slate
        :icon="isExpanded ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'"
        trailing-icon
        :label="
          isExpanded
            ? t(
                'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.COLLAPSE',
                'Hide templates'
              )
            : t(
                'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.EXPAND',
                'Show templates'
              )
        "
        @click="toggleExpanded"
      />
    </div>

    <!-- Expanded Cards Grid -->
    <div
      v-if="isExpanded"
      class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-4"
    >
      <TemplateCard
        v-for="template in SCENARIO_TEMPLATES"
        :key="template.id"
        :template="template"
        :tools="tools"
        @use="onUseTemplate"
      />
    </div>
  </div>
</template>

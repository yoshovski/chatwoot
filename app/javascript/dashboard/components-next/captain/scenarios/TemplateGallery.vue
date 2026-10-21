<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useUISettings } from 'dashboard/composables/useUISettings';
import Button from 'dashboard/components-next/button/Button.vue';
import TemplateCard from './TemplateCard.vue';
import { SCENARIO_TEMPLATES, isTemplateAvailable } from './scenarioTemplates';

const props = defineProps({
  tools: {
    type: Array,
    default: () => [],
  },
  hasScenarios: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['useTemplate', 'describe']);

const { t } = useI18n();
const { uiSettings, updateUISettings } = useUISettings();

// Until the user toggles it, show the gallery only while there is nothing to manage yet.
const isExpanded = computed(
  () => uiSettings.value?.show_scenarios_suggestions ?? !props.hasScenarios
);

// Templates that need an integration this account doesn't have only add noise.
const availableTemplates = computed(() =>
  SCENARIO_TEMPLATES.filter(template =>
    isTemplateAvailable(template, props.tools)
  )
);

const toggleExpanded = () => {
  updateUISettings({ show_scenarios_suggestions: !isExpanded.value });
};
</script>

<template>
  <section class="flex flex-col gap-3 w-full">
    <div class="flex items-center justify-between gap-4">
      <div class="flex flex-col gap-0.5">
        <h2 class="text-sm font-medium text-n-slate-12 m-0">
          {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.GALLERY_TITLE') }}
        </h2>
        <p class="text-sm text-n-slate-11 m-0">
          {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.GALLERY_DESCRIPTION') }}
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
            ? t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.COLLAPSE')
            : t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.EXPAND')
        "
        @click="toggleExpanded"
      />
    </div>

    <div
      v-if="isExpanded"
      class="grid grid-cols-1 gap-2 sm:grid-cols-2 xl:grid-cols-3"
    >
      <button
        type="button"
        class="flex items-start w-full h-full gap-3 p-3 text-start rounded-xl border border-dashed border-n-strong bg-transparent hover:bg-n-alpha-1 transition-colors motion-reduce:transition-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
        data-test="template-describe"
        @click="emit('describe')"
      >
        <span
          class="flex items-center justify-center rounded-lg size-8 shrink-0 bg-n-brand/10 text-n-blue-11"
        >
          <span class="i-lucide-sparkles size-4" />
        </span>
        <span class="flex flex-col min-w-0 gap-0.5">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.DESCRIBE.TITLE') }}
          </span>
          <span class="text-xs text-n-slate-11 line-clamp-2">
            {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.DESCRIBE.TAGLINE') }}
          </span>
        </span>
      </button>
      <TemplateCard
        v-for="template in availableTemplates"
        :key="template.id"
        :template="template"
        :tools="tools"
        @use="emit('useTemplate', $event)"
      />
    </div>
  </section>
</template>

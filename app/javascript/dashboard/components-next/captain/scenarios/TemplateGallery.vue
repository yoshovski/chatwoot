<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useUISettings } from 'dashboard/composables/useUISettings';
import Button from 'dashboard/components-next/button/Button.vue';
import TemplateCard from './TemplateCard.vue';
import { SCENARIO_TEMPLATES } from './scenarioTemplates';

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
      class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-3"
    >
      <TemplateCard
        v-for="template in SCENARIO_TEMPLATES"
        :key="template.id"
        :template="template"
        :tools="tools"
        @use="emit('useTemplate', $event)"
      />
      <button
        type="button"
        class="flex flex-col gap-3 h-full w-full p-4 text-start rounded-xl border border-dashed border-n-strong bg-transparent hover:bg-n-alpha-1 transition-colors motion-reduce:transition-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
        data-test="template-describe"
        @click="emit('describe')"
      >
        <span
          class="flex items-center justify-center size-9 rounded-lg bg-n-brand/10 text-n-blue-11"
        >
          <span class="i-lucide-sparkles size-5" />
        </span>
        <span class="flex flex-col gap-1">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.DESCRIBE.TITLE') }}
          </span>
          <span class="text-sm text-n-slate-11 line-clamp-2">
            {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.DESCRIBE.TAGLINE') }}
          </span>
        </span>
      </button>
    </div>
  </section>
</template>

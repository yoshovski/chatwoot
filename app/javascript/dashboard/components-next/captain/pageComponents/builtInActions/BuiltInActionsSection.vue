<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import SidePanel from 'dashboard/components-next/side-panel/SidePanel.vue';
import {
  TOOL_CATEGORIES,
  toolGroup,
} from 'dashboard/components-next/captain/scenarios/builtInActions';

// Read-only list of what the AI agent can do without setup. Behaviour is fixed by ChatOctave; scenarios name the
// actions and their values, so there are no per-agent switches here.
const { t } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();

const tools = useMapGetter('captainTools/getRecords');
const helpPanel = ref(null);

const builtInTools = computed(() =>
  (tools.value || []).filter(tool => !tool.custom && !tool.mcp)
);

// The decision table from the behaviour model: which tool fits which job.
const helpRows = computed(() => [
  {
    key: 'BEHAVIOUR',
    use: t('CAPTAIN.BUILT_IN_ACTIONS.HELP.ROWS.BEHAVIOUR.USE'),
    when: t('CAPTAIN.BUILT_IN_ACTIONS.HELP.ROWS.BEHAVIOUR.WHEN'),
    example: t('CAPTAIN.BUILT_IN_ACTIONS.HELP.ROWS.BEHAVIOUR.EXAMPLE'),
  },
  {
    key: 'LIMIT',
    use: t('CAPTAIN.BUILT_IN_ACTIONS.HELP.ROWS.LIMIT.USE'),
    when: t('CAPTAIN.BUILT_IN_ACTIONS.HELP.ROWS.LIMIT.WHEN'),
    example: t('CAPTAIN.BUILT_IN_ACTIONS.HELP.ROWS.LIMIT.EXAMPLE'),
  },
  {
    key: 'SCENARIO',
    use: t('CAPTAIN.BUILT_IN_ACTIONS.HELP.ROWS.SCENARIO.USE'),
    when: t('CAPTAIN.BUILT_IN_ACTIONS.HELP.ROWS.SCENARIO.WHEN'),
    example: t('CAPTAIN.BUILT_IN_ACTIONS.HELP.ROWS.SCENARIO.EXAMPLE'),
  },
  {
    key: 'ACTION',
    use: t('CAPTAIN.BUILT_IN_ACTIONS.HELP.ROWS.ACTION.USE'),
    when: t('CAPTAIN.BUILT_IN_ACTIONS.HELP.ROWS.ACTION.WHEN'),
    example: t('CAPTAIN.BUILT_IN_ACTIONS.HELP.ROWS.ACTION.EXAMPLE'),
  },
  {
    key: 'AUTOMATION',
    use: t('CAPTAIN.BUILT_IN_ACTIONS.HELP.ROWS.AUTOMATION.USE'),
    when: t('CAPTAIN.BUILT_IN_ACTIONS.HELP.ROWS.AUTOMATION.WHEN'),
    example: t('CAPTAIN.BUILT_IN_ACTIONS.HELP.ROWS.AUTOMATION.EXAMPLE'),
  },
  {
    key: 'KNOWLEDGE',
    use: t('CAPTAIN.BUILT_IN_ACTIONS.HELP.ROWS.KNOWLEDGE.USE'),
    when: t('CAPTAIN.BUILT_IN_ACTIONS.HELP.ROWS.KNOWLEDGE.WHEN'),
    example: t('CAPTAIN.BUILT_IN_ACTIONS.HELP.ROWS.KNOWLEDGE.EXAMPLE'),
  },
]);

const categorized = computed(() =>
  TOOL_CATEGORIES.map(category => ({
    ...category,
    tools: builtInTools.value.filter(tool => toolGroup(tool) === category.key),
  })).filter(category => category.tools.length)
);

const useInScenario = () =>
  router.push({
    name: 'captain_assistants_scenarios_index',
    params: route.params,
  });

onMounted(() => {
  if (!(tools.value || []).length) store.dispatch('captainTools/getTools');
});
</script>

<template>
  <section class="flex flex-col gap-6" data-test="built-in-actions">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <p class="max-w-3xl m-0 text-sm text-n-slate-11">
        {{
          t('CAPTAIN.AGENT_UX.TOOLS.INTRO.BUILT_IN', {
            count: builtInTools.length,
          })
        }}
      </p>
      <div class="flex gap-2 shrink-0">
        <Button
          sm
          faded
          slate
          icon="i-lucide-circle-help"
          :label="t('CAPTAIN.BUILT_IN_ACTIONS.HELP.TOGGLE')"
          data-test="built-in-help-toggle"
          @click="helpPanel.open()"
        />
        <Button
          sm
          faded
          slate
          icon="i-lucide-git-branch"
          :label="t('CAPTAIN.BUILT_IN_ACTIONS.USE_IN_SCENARIO')"
          @click="useInScenario"
        />
      </div>
    </div>

    <div
      v-for="category in categorized"
      :key="category.key"
      class="flex flex-col gap-2"
    >
      <h3
        class="flex items-center gap-1.5 m-0 text-sm font-semibold text-n-slate-12"
      >
        <span
          :class="category.icon"
          class="size-4 text-n-slate-10"
          aria-hidden="true"
        />
        {{ t(`CAPTAIN.AGENT_UX.TOOLS.CATEGORIES.${category.key}`) }}
      </h3>
      <ul class="grid gap-2 p-0 m-0 list-none sm:grid-cols-2 xl:grid-cols-3">
        <li
          v-for="tool in category.tools"
          :key="tool.id"
          class="flex items-start gap-3 px-3 py-2.5 rounded-xl bg-n-alpha-1"
          data-test="built-in-action-card"
        >
          <span class="w-5 text-base leading-5 text-center shrink-0">
            {{ tool.emoji }}
          </span>
          <span class="flex flex-col min-w-0">
            <span class="text-sm font-medium text-n-slate-12">
              {{ tool.title }}
            </span>
            <span class="text-xs text-n-slate-11 line-clamp-2">
              {{ tool.description }}
            </span>
          </span>
        </li>
      </ul>
    </div>

    <SidePanel
      ref="helpPanel"
      :title="t('CAPTAIN.BUILT_IN_ACTIONS.HELP.TOGGLE')"
      width="3xl"
    >
      <div class="flex flex-col gap-3" data-test="built-in-help">
        <div
          v-for="row in helpRows"
          :key="row.key"
          class="flex flex-col gap-1 p-4 rounded-xl bg-n-alpha-1"
        >
          <span class="text-sm font-medium text-n-slate-12">{{ row.use }}</span>
          <span class="text-sm text-n-slate-11">{{ row.when }}</span>
          <span class="text-xs italic text-n-slate-10">{{ row.example }}</span>
        </div>
      </div>
    </SidePanel>
  </section>
</template>

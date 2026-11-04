<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';

// Read-only list of what the AI agent can do without setup. Behaviour is fixed by ChatOctave; scenarios name the
// actions and their values, so there are no per-agent switches here.
const { t } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();

const tools = useMapGetter('captainTools/getRecords');
const showHelp = ref(false);

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
  <section class="flex flex-col gap-3" data-test="built-in-actions">
    <div class="flex items-center justify-between gap-2">
      <div class="flex flex-col gap-0.5">
        <h2 class="mb-0 text-sm font-medium text-n-slate-12">
          {{ t('CAPTAIN.BUILT_IN_ACTIONS.TITLE') }}
        </h2>
        <p class="mb-0 text-sm text-n-slate-11">
          {{ t('CAPTAIN.BUILT_IN_ACTIONS.DESCRIPTION') }}
        </p>
      </div>
      <Button
        xs
        link
        :label="t('CAPTAIN.BUILT_IN_ACTIONS.HELP.TOGGLE')"
        data-test="built-in-help-toggle"
        @click="showHelp = !showHelp"
      />
    </div>

    <div
      v-if="showHelp"
      class="overflow-x-auto border rounded-lg border-n-weak"
      data-test="built-in-help"
    >
      <table class="w-full text-sm text-start">
        <thead class="text-n-slate-11">
          <tr>
            <th class="px-3 py-2 font-medium text-start">
              {{ t('CAPTAIN.BUILT_IN_ACTIONS.HELP.USE') }}
            </th>
            <th class="px-3 py-2 font-medium text-start">
              {{ t('CAPTAIN.BUILT_IN_ACTIONS.HELP.WHEN') }}
            </th>
            <th class="px-3 py-2 font-medium text-start">
              {{ t('CAPTAIN.BUILT_IN_ACTIONS.HELP.EXAMPLE') }}
            </th>
          </tr>
        </thead>
        <tbody class="text-n-slate-12">
          <tr
            v-for="row in helpRows"
            :key="row.key"
            class="border-t border-n-weak"
          >
            <td class="px-3 py-2 font-medium">{{ row.use }}</td>
            <td class="px-3 py-2">{{ row.when }}</td>
            <td class="px-3 py-2 text-n-slate-11">{{ row.example }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
      <div
        v-for="tool in builtInTools"
        :key="tool.id"
        class="flex flex-col gap-2 p-3 border rounded-xl border-n-weak bg-n-solid-1"
        data-test="built-in-action-card"
      >
        <div class="flex items-center gap-2">
          <span v-if="tool.emoji" class="text-base leading-none">
            {{ tool.emoji }}
          </span>
          <span class="text-sm font-medium text-n-slate-12">
            {{ tool.title }}
          </span>
        </div>
        <p class="mb-0 text-xs text-n-slate-11">{{ tool.description }}</p>
        <Button
          xs
          link
          class="self-start"
          :label="t('CAPTAIN.BUILT_IN_ACTIONS.USE_IN_SCENARIO')"
          @click="useInScenario"
        />
      </div>
    </div>
  </section>
</template>

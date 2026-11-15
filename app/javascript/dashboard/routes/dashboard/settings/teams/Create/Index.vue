<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import TeamWizard from '../TeamWizard.vue';

const { t } = useI18n();

const steps = computed(() => [
  {
    route: 'settings_teams_new',
    label: t('TEAMS_SETTINGS.WIZARD.STEPS.DETAILS'),
  },
  {
    route: 'settings_teams_add_agents',
    label: t('TEAMS_SETTINGS.WIZARD.STEPS.MEMBERS'),
  },
  {
    route: 'settings_teams_finish',
    label: t('TEAMS_SETTINGS.WIZARD.STEPS.DONE'),
  },
]);
</script>

<template>
  <TeamWizard
    :title="t('TEAMS_SETTINGS.WIZARD.NEW_TITLE')"
    :description="t('TEAMS_SETTINGS.WIZARD.NEW_SUBTITLE')"
    :steps="steps"
  />
</template>

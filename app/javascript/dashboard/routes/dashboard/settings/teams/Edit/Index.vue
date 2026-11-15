<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import TeamWizard from '../TeamWizard.vue';

const { t } = useI18n();

const steps = computed(() => [
  {
    route: 'settings_teams_edit',
    label: t('TEAMS_SETTINGS.WIZARD.STEPS.DETAILS'),
  },
  {
    route: 'settings_teams_edit_members',
    label: t('TEAMS_SETTINGS.WIZARD.STEPS.MEMBERS'),
  },
  {
    route: 'settings_teams_edit_finish',
    label: t('TEAMS_SETTINGS.WIZARD.STEPS.DONE'),
  },
]);
</script>

<template>
  <TeamWizard
    :title="t('TEAMS_SETTINGS.WIZARD.EDIT_TITLE')"
    :description="t('TEAMS_SETTINGS.WIZARD.EDIT_SUBTITLE')"
    :steps="steps"
  />
</template>

<script>
import { useAlert } from 'dashboard/composables';
import TeamForm from '../TeamForm.vue';
import router from '../../../../index';

export default {
  components: {
    TeamForm,
  },
  data() {
    return {
      enabledFeatures: {},
    };
  },
  methods: {
    async createTeam(data) {
      try {
        const team = await this.$store.dispatch('teams/create', {
          ...data,
        });

        router.replace({
          name: 'settings_teams_add_agents',
          params: {
            page: 'new',
            teamId: team.id,
          },
        });
      } catch (error) {
        useAlert(this.$t('TEAMS_SETTINGS.TEAM_FORM.ERROR_MESSAGE'));
      }
    },
  },
};
</script>

<template>
  <div class="w-full">
    <div class="flex w-full">
      <TeamForm
        :on-submit="createTeam"
        :submit-in-progress="false"
        :submit-button-text="$t('TEAMS_SETTINGS.FORM.SUBMIT_CREATE')"
      />
    </div>
  </div>
</template>

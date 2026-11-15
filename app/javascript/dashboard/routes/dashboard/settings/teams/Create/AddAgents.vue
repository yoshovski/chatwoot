<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';

import router from '../../../../index';
import FormLayout from 'dashboard/components-next/kit/FormLayout.vue';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';
import AgentSelector from '../AgentSelector.vue';
import { useVuelidate } from '@vuelidate/core';

export default {
  components: {
    FormLayout,
    SectionCard,
    AgentSelector,
  },
  validations: {
    selectedAgents: {
      isEmpty() {
        return !!this.selectedAgents.length;
      },
    },
  },

  setup() {
    return { v$: useVuelidate() };
  },

  data() {
    return {
      selectedAgents: [],
      isCreating: false,
    };
  },

  computed: {
    ...mapGetters({
      agentList: 'agents/getAgents',
    }),

    teamId() {
      return this.$route.params.teamId;
    },
    cardTitle() {
      return this.$t('TEAMS_SETTINGS.WIZARD.MEMBERS_CARD', {
        teamName: this.currentTeam.name,
      });
    },
    currentTeam() {
      return this.$store.getters['teams/getTeam'](this.teamId);
    },
  },

  mounted() {
    this.$store.dispatch('agents/get');
  },

  methods: {
    updateSelectedAgents(newAgentList) {
      this.v$.selectedAgents.$touch();
      this.selectedAgents = [...newAgentList];
    },
    selectAllAgents() {
      this.selectedAgents = this.agentList.map(agent => agent.id);
    },
    async addAgents() {
      this.isCreating = true;
      const { teamId, selectedAgents } = this;

      try {
        await this.$store.dispatch('teamMembers/create', {
          teamId,
          agentsList: selectedAgents,
        });
        router.replace({
          name: 'settings_teams_finish',
          params: {
            page: 'new',
            teamId,
          },
        });
        this.$store.dispatch('teams/get');
      } catch (error) {
        useAlert(error.message);
      }
      this.isCreating = false;
    },
  },
};
</script>

<template>
  <FormLayout
    :save-label="$t('TEAMS_SETTINGS.ADD.BUTTON_TEXT')"
    :saving="isCreating"
    :disabled="!selectedAgents.length"
    @save="addAgents"
  >
    <SectionCard :title="cardTitle">
      <p class="mb-0 text-sm text-n-slate-11">
        {{ $t('TEAMS_SETTINGS.WIZARD.MEMBERS_HINT') }}
      </p>
      <p v-if="v$.selectedAgents.$error" class="mb-0 text-sm text-n-ruby-11">
        {{ $t('TEAMS_SETTINGS.ADD.AGENT_VALIDATION_ERROR') }}
      </p>
      <AgentSelector
        :agent-list="agentList"
        :selected-agents="selectedAgents"
        :update-selected-agents="updateSelectedAgents"
      />
    </SectionCard>
    <template #status>
      {{
        $t('TEAMS_SETTINGS.WIZARD.SELECTED_COUNT', {
          selected: selectedAgents.length,
          total: agentList.length,
        })
      }}
    </template>
  </FormLayout>
</template>

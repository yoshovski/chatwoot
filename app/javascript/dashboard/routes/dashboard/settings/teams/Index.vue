<script setup>
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { computed, onMounted, ref } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import EmojiIcon from 'dashboard/components-next/emoji-icon-picker/EmojiIcon.vue';
import PageHeader from 'next/kit/PageHeader.vue';
import TableCard from 'next/kit/TableCard.vue';

const store = useStore();
const { t } = useI18n();
const { isAdmin } = useAdmin();

const loading = ref({});
const isFetching = ref(true);
const fetchFailed = ref(false);

const teamsList = useMapGetter('teams/getTeams');

const columns = computed(() => [
  { key: 'name', label: t('TEAMS_SETTINGS.PAGE.COLUMNS.NAME') },
  {
    key: 'assignment',
    label: t('TEAMS_SETTINGS.PAGE.COLUMNS.ASSIGNMENT'),
    class: 'w-52',
  },
  {
    key: 'actions',
    label: t('TEAMS_SETTINGS.PAGE.COLUMNS.ACTIONS'),
    end: true,
    hideLabel: true,
    class: 'w-24',
  },
]);

const loadTeams = async () => {
  isFetching.value = true;
  fetchFailed.value = false;
  try {
    await store.dispatch('teams/get');
  } catch {
    fetchFailed.value = true;
  } finally {
    isFetching.value = false;
  }
};

onMounted(loadTeams);

const deleteTeam = async ({ id }) => {
  try {
    loading.value[id] = true;
    await store.dispatch('teams/delete', id);
    useAlert(t('TEAMS_SETTINGS.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('TEAMS_SETTINGS.DELETE.API.ERROR_MESSAGE'));
  } finally {
    loading.value[id] = false;
  }
};

const showDeletePopup = ref(false);
const selectedTeam = ref({});

const openDelete = team => {
  showDeletePopup.value = true;
  selectedTeam.value = team;
};

const closeDelete = () => {
  showDeletePopup.value = false;
  selectedTeam.value = {};
};

const confirmDeletion = () => {
  deleteTeam(selectedTeam.value);
  closeDelete();
};

const deleteConfirmText = computed(
  () => `${t('TEAMS_SETTINGS.DELETE.CONFIRM.YES')} ${selectedTeam.value.name}`
);

const deleteRejectText = computed(() => t('TEAMS_SETTINGS.DELETE.CONFIRM.NO'));

const confirmDeleteTitle = computed(() =>
  t('TEAMS_SETTINGS.DELETE.CONFIRM.TITLE', {
    teamName: selectedTeam.value.name,
  })
);

const confirmPlaceHolderText = computed(() =>
  t('TEAMS_SETTINGS.DELETE.CONFIRM.PLACE_HOLDER', {
    teamName: selectedTeam.value.name,
  })
);
</script>

<template>
  <section class="flex w-full min-w-0 flex-col gap-5 pb-5 pt-2">
    <PageHeader
      :title="t('TEAMS_SETTINGS.PAGE.TITLE')"
      :description="t('TEAMS_SETTINGS.PAGE.SUBTITLE')"
    >
      <template v-if="isAdmin" #action>
        <router-link :to="{ name: 'settings_teams_new' }">
          <Button
            :label="t('TEAMS_SETTINGS.PAGE.NEW')"
            icon="i-lucide-plus"
            size="sm"
          />
        </router-link>
      </template>
    </PageHeader>

    <TableCard
      :columns="columns"
      :rows="teamsList"
      :loading="isFetching && !teamsList.length"
      :error="fetchFailed"
      :search-keys="['name', 'description']"
      :search-placeholder="t('TEAMS_SETTINGS.PAGE.SEARCH')"
      :count="t('TEAMS_SETTINGS.PAGE.COUNT', { n: teamsList.length })"
      :loading-text="t('TEAMS_SETTINGS.PAGE.LOADING')"
      :error-text="t('TEAMS_SETTINGS.PAGE.LOAD_ERROR')"
      :retry-label="t('TEAMS_SETTINGS.PAGE.RETRY')"
      :empty-title="t('TEAMS_SETTINGS.PAGE.EMPTY_TITLE')"
      :empty-description="t('TEAMS_SETTINGS.PAGE.EMPTY_DESCRIPTION')"
      empty-icon="i-lucide-users-round"
      :no-results-text="t('TEAMS_SETTINGS.PAGE.NO_RESULTS')"
      @retry="loadTeams"
    >
      <template v-if="isAdmin" #empty>
        <router-link :to="{ name: 'settings_teams_new' }">
          <Button
            :label="t('TEAMS_SETTINGS.PAGE.NEW')"
            icon="i-lucide-plus"
            size="sm"
          />
        </router-link>
      </template>
      <template #cell-name="{ row: team }">
        <div class="flex items-center gap-3">
          <span
            class="grid size-9 shrink-0 place-items-center rounded-xl bg-n-alpha-2 text-lg"
          >
            <EmojiIcon
              v-if="team.icon"
              :value="team.icon"
              :color="team.icon_color"
              class="size-5"
            />
            <Icon
              v-else
              icon="i-lucide-users-round"
              class="size-4 text-n-slate-11"
            />
          </span>
          <div class="flex min-w-0 flex-col">
            <span class="truncate font-medium capitalize text-n-slate-12">
              {{ team.name }}
            </span>
            <span
              v-if="team.description"
              class="truncate text-xs text-n-slate-11"
            >
              {{ team.description }}
            </span>
          </div>
        </div>
      </template>
      <template #cell-assignment="{ row: team }">
        <span class="text-n-slate-11">
          {{
            team.allow_auto_assign
              ? t('TEAMS_SETTINGS.PAGE.AUTO_ASSIGN')
              : t('TEAMS_SETTINGS.PAGE.MANUAL_ASSIGN')
          }}
        </span>
      </template>
      <template #cell-actions="{ row: team }">
        <div v-if="isAdmin" class="flex justify-end gap-1">
          <router-link
            :to="{ name: 'settings_teams_edit', params: { teamId: team.id } }"
          >
            <Button
              v-tooltip.top="t('TEAMS_SETTINGS.PAGE.EDIT')"
              :aria-label="t('TEAMS_SETTINGS.PAGE.EDIT')"
              icon="i-lucide-pencil"
              variant="ghost"
              color="slate"
              size="sm"
            />
          </router-link>
          <Button
            v-tooltip.top="t('TEAMS_SETTINGS.PAGE.DELETE')"
            :aria-label="t('TEAMS_SETTINGS.PAGE.DELETE')"
            icon="i-lucide-trash-2"
            variant="ghost"
            color="ruby"
            size="sm"
            :is-loading="loading[team.id]"
            @click="openDelete(team)"
          />
        </div>
      </template>
    </TableCard>

    <woot-confirm-delete-modal
      v-if="showDeletePopup"
      v-model:show="showDeletePopup"
      :title="confirmDeleteTitle"
      :message="t('TEAMS_SETTINGS.DELETE.CONFIRM.MESSAGE')"
      :confirm-text="deleteConfirmText"
      :reject-text="deleteRejectText"
      :confirm-value="selectedTeam.name"
      :confirm-place-holder-text="confirmPlaceHolderText"
      @on-confirm="confirmDeletion"
      @on-close="closeDelete"
    />
  </section>
</template>

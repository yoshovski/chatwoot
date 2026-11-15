<script setup>
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import EmptyState from 'dashboard/components-next/kit/EmptyState.vue';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';

const { t } = useI18n();
</script>

<template>
  <SectionCard class="max-w-[40rem]">
    <EmptyState
      tone="success"
      icon="i-lucide-circle-check"
      :title="t('TEAMS_SETTINGS.WIZARD.DONE_TITLE')"
      :description="t('TEAMS_SETTINGS.WIZARD.DONE_MESSAGE')"
    >
      <router-link :to="{ name: 'settings_teams_list' }">
        <Button :label="t('TEAMS_SETTINGS.WIZARD.DONE_BUTTON')" size="sm" />
      </router-link>
    </EmptyState>
  </SectionCard>
</template>

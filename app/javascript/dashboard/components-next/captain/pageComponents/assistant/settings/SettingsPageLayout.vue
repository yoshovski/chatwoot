<script setup>
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter } from 'dashboard/composables/store';
import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import SettingsHeader from 'dashboard/components-next/captain/pageComponents/settings/SettingsHeader.vue';
import VerticalTabs from 'dashboard/components-next/vertical-tabs/VerticalTabs.vue';
import AssistantProfileCard from './AssistantProfileCard.vue';
import { useAssistantSettings } from 'dashboard/routes/dashboard/captain/assistants/settings/useAssistantSettings';

defineProps({
  heading: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    default: '',
  },
});

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { isCloudFeatureEnabled } = useAccount();

const uiFlags = useMapGetter('captainAssistants/getUIFlags');
const { assistant } = useAssistantSettings();
const isFetching = computed(() => uiFlags.value.fetchingItem);

const isCaptainV2Enabled = computed(() =>
  isCloudFeatureEnabled(FEATURE_FLAGS.CAPTAIN_V2)
);

const assistantName = computed(() => assistant.value?.name || '');

const tabs = computed(() => {
  const name = assistantName.value;
  const groups = {
    identity: t('CAPTAIN.ASSISTANTS.SETTINGS.GROUPS.IDENTITY', { name }),
    when: t('CAPTAIN.ASSISTANTS.SETTINGS.GROUPS.WHEN'),
    how: t('CAPTAIN.ASSISTANTS.SETTINGS.GROUPS.HOW', { name }),
  };
  const v2 = isCaptainV2Enabled.value;

  return [
    {
      id: 'captain_assistants_settings_index',
      group: groups.identity,
      icon: 'i-lucide-id-card',
      label: t('CAPTAIN.ASSISTANTS.SETTINGS.TABS.IDENTITY'),
    },
    v2 && {
      id: 'captain_assistants_guidelines_index',
      group: groups.identity,
      icon: 'i-lucide-message-circle',
      label: t('CAPTAIN.ASSISTANTS.SETTINGS.TABS.BEHAVIOR'),
    },
    {
      id: 'captain_assistants_settings_schedule_index',
      group: groups.when,
      icon: 'i-lucide-clock',
      label: t('CAPTAIN.ASSISTANTS.SETTINGS.TABS.WORKING_HOURS'),
    },
    {
      id: 'captain_assistants_settings_audience_index',
      group: groups.when,
      icon: 'i-lucide-users',
      label: t('CAPTAIN.ASSISTANTS.SETTINGS.TABS.AUDIENCE', { name }),
    },
    v2 && {
      id: 'captain_assistants_scenarios_index',
      group: groups.how,
      icon: 'i-lucide-git-branch',
      trailingIcon: 'i-lucide-arrow-up-right',
      label: t('CAPTAIN.ASSISTANTS.SETTINGS.TABS.SCENARIOS'),
    },
    v2 && {
      id: 'captain_assistants_guardrails_index',
      group: groups.how,
      icon: 'i-lucide-shield',
      label: t('CAPTAIN.ASSISTANTS.SETTINGS.TABS.BOUNDARIES'),
    },
    {
      id: 'captain_assistants_settings_system_index',
      group: groups.how,
      icon: 'i-lucide-arrow-right-left',
      label: t('CAPTAIN.ASSISTANTS.SETTINGS.TABS.HANDOVER'),
    },
    {
      id: 'captain_assistants_settings_after_chat_index',
      group: groups.how,
      icon: 'i-lucide-check-check',
      label: t('CAPTAIN.ASSISTANTS.SETTINGS.TABS.AFTER_CHAT'),
    },
  ].filter(Boolean);
});

const activeTab = computed({
  get: () => route.name,
  set: name =>
    router.push({
      name,
      params: {
        accountId: route.params.accountId,
        assistantId: route.params.assistantId,
      },
    }),
});
</script>

<template>
  <PageLayout
    :header-title="t('CAPTAIN.ASSISTANTS.SETTINGS.HEADER')"
    :is-fetching="isFetching"
    :show-know-more="false"
    :show-pagination-footer="false"
  >
    <template #body>
      <AssistantProfileCard
        v-if="assistant?.id"
        :assistant="assistant"
        class="mb-6"
      />
      <VerticalTabs
        v-model="activeTab"
        :tabs="tabs"
        content-class="max-w-[52rem] pb-8"
      >
        <template #[activeTab]>
          <div class="flex flex-col w-full gap-6">
            <SettingsHeader :heading="heading" :description="description" />
            <slot />
          </div>
        </template>
      </VerticalTabs>
    </template>
  </PageLayout>
</template>

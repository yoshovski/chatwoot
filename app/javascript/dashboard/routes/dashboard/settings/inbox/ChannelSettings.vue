<script setup>
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys -- Fixed channel groups and health keys. */
import { computed, nextTick, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import InboxesAPI from 'dashboard/api/inboxes';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { INBOX_TYPES, getInboxIdentifier } from 'dashboard/helper/inbox';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import {
  channelHealth,
  CHANNEL_GROUPS,
  channelGroupForTab,
} from 'next/Channels/channelHealth';
import PageHeader from 'next/kit/PageHeader.vue';
import SectionCard from 'next/kit/SectionCard.vue';
import StatusPill from 'next/kit/StatusPill.vue';
import EmptyState from 'next/kit/EmptyState.vue';
import Button from 'next/button/Button.vue';
import ChannelAgentConnection from 'next/Channels/ChannelAgentConnection.vue';
import ChannelDelete from 'next/Channels/ChannelDelete.vue';
import Settings from './Settings.vue';
import WebsiteChannelSettings from './WebsiteChannelSettings.vue';
import CollaboratorsPage from './settingsPage/CollaboratorsPage.vue';
import WeeklyAvailability from './components/WeeklyAvailability.vue';
import CustomerSatisfactionPage from './settingsPage/CustomerSatisfactionPage.vue';
import WhatsappCallingPage from './settingsPage/WhatsappCallingPage.vue';

const store = useStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const loading = ref(true);
const error = ref(false);
const inbox = computed(() =>
  store.getters['inboxes/getInbox'](route.params.inboxId)
);
const modern = computed(
  () =>
    [INBOX_TYPES.EMAIL, INBOX_TYPES.WHATSAPP].includes(
      inbox.value.channel_type
    ) ||
    (inbox.value.channel_type === INBOX_TYPES.TWILIO &&
      inbox.value.medium === 'whatsapp')
);
const latestHealth = ref(null);
const health = computed(() =>
  channelHealth(
    latestHealth.value
      ? {
          ...inbox.value,
          phone_number_health: latestHealth.value.data,
          health_check_failed: !!latestHealth.value.error,
        }
      : inbox.value
  )
);
const group = computed(() => channelGroupForTab(route.params.tab));
const accountId = useMapGetter('getCurrentAccountId');
const hasCaptain = computed(() =>
  store.getters['accounts/isFeatureEnabledonAccount'](
    accountId.value,
    FEATURE_FLAGS.CAPTAIN
  )
);
const hasCalling = computed(
  () =>
    inbox.value.channel_type === INBOX_TYPES.WHATSAPP &&
    inbox.value.provider === 'whatsapp_cloud' &&
    store.getters['accounts/isFeatureEnabledonAccount'](
      accountId.value,
      FEATURE_FLAGS.CHANNEL_VOICE
    )
);
const load = async () => {
  loading.value = true;
  error.value = false;
  try {
    const { data } = await InboxesAPI.get();
    store.commit('inboxes/SET_INBOXES', data.payload);
  } catch {
    error.value = true;
  } finally {
    loading.value = false;
  }
};
const changeGroup = key =>
  router.replace({
    name: 'settings_inbox_show',
    params: { ...route.params, tab: key },
  });
const onTabKeydown = async (event, index) => {
  let next;
  if (event.key === 'ArrowRight') next = (index + 1) % CHANNEL_GROUPS.length;
  else if (event.key === 'ArrowLeft')
    next = (index + CHANNEL_GROUPS.length - 1) % CHANNEL_GROUPS.length;
  else if (event.key === 'Home') next = 0;
  else if (event.key === 'End') next = CHANNEL_GROUPS.length - 1;
  else return;
  event.preventDefault();
  const { key } = CHANNEL_GROUPS[next];
  await changeGroup(key);
  await nextTick();
  document.getElementById(`channel-tab-${key}`).focus();
};
onMounted(load);
</script>

<template>
  <div class="flex w-full min-w-0 flex-col gap-5 py-4">
    <router-link
      v-if="inbox.channel_type !== INBOX_TYPES.WEB"
      :to="{ name: 'settings_inbox_list' }"
      class="self-start text-sm font-medium text-n-blue-11"
    >
      {{ t('CHANNELS.BACK') }}
    </router-link>
    <p
      v-if="loading"
      class="m-0 py-12 text-center text-sm text-n-slate-11"
      role="status"
    >
      {{ t('CHANNELS.LOADING') }}
    </p>
    <EmptyState
      v-else-if="error"
      :title="t('CHANNELS.LOAD_ERROR')"
      tone="error"
    >
      <Button :label="t('CHANNELS.RETRY')" size="sm" @click="load" />
    </EmptyState>
    <EmptyState v-else-if="!inbox.id" :title="t('CHANNELS.NOT_FOUND')" />
    <WebsiteChannelSettings
      v-else-if="inbox.channel_type === INBOX_TYPES.WEB"
      :inbox="inbox"
    />
    <template v-else-if="modern">
      <PageHeader :title="inbox.name" :description="getInboxIdentifier(inbox)">
        <template #action>
          <StatusPill :status="health.tone" :label="t(health.label)" />
        </template>
      </PageHeader>
      <p class="m-0 text-sm text-n-slate-11">{{ t(health.reason) }}</p>
      <div
        role="tablist"
        :aria-label="t('CHANNELS.SETTINGS')"
        class="flex flex-wrap gap-2"
      >
        <Button
          v-for="(tab, index) in CHANNEL_GROUPS"
          :id="`channel-tab-${tab.key}`"
          :key="tab.key"
          role="tab"
          :aria-selected="group === tab.key"
          :tabindex="group === tab.key ? 0 : -1"
          :aria-controls="`channel-panel-${tab.key}`"
          :label="t(tab.label)"
          :variant="group === tab.key ? 'solid' : 'ghost'"
          :color="group === tab.key ? 'blue' : 'slate'"
          size="sm"
          @click="changeGroup(tab.key)"
          @keydown="onTabKeydown($event, index)"
        />
      </div>
      <!-- Keep forms mounted across group changes so drafts survive switching tabs. -->
      <div
        v-show="group === 'connection'"
        id="channel-panel-connection"
        role="tabpanel"
        aria-labelledby="channel-tab-connection"
        class="flex min-w-0 flex-col gap-5"
      >
        <ChannelAgentConnection v-if="hasCaptain" :inbox="inbox" />
        <SectionCard :title="t('CHANNELS.GROUPS.CONNECTION')">
          <Settings
            embedded
            section="configuration"
            @health-updated="latestHealth = $event"
          />
        </SectionCard>
        <SectionCard v-if="hasCalling" :title="t('INBOX_MGMT.TABS.CALLS')">
          <WhatsappCallingPage :inbox="inbox" />
        </SectionCard>
      </div>
      <div
        v-show="group === 'messages'"
        id="channel-panel-messages"
        role="tabpanel"
        aria-labelledby="channel-tab-messages"
        class="flex min-w-0 flex-col gap-5"
      >
        <SectionCard :title="t('CHANNELS.GROUPS.MESSAGES')">
          <Settings embedded section="inbox-settings" />
        </SectionCard>
        <SectionCard :title="t('CHANNELS.CUSTOMER_RATING')">
          <CustomerSatisfactionPage :inbox="inbox" />
        </SectionCard>
      </div>
      <div
        v-show="group === 'team'"
        id="channel-panel-team"
        role="tabpanel"
        aria-labelledby="channel-tab-team"
        class="flex min-w-0 flex-col gap-5"
      >
        <SectionCard :title="t('CHANNELS.TEAM')">
          <CollaboratorsPage :inbox="inbox" />
        </SectionCard>
        <SectionCard
          :title="t('CHANNELS.HOURS')"
          class="[&_.mx-6]:!mx-0 [&_table]:min-w-[38rem] [&_form]:overflow-x-auto"
        >
          <WeeklyAvailability :inbox="inbox" />
        </SectionCard>
      </div>
      <ChannelDelete :inbox="inbox" />
    </template>
    <template v-else>
      <Settings />
      <ChannelDelete :inbox="inbox" />
    </template>
  </div>
</template>

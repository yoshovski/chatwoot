<script setup>
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys -- Health and status keys come from the fixed channel health map. */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import InboxesAPI from 'dashboard/api/inboxes';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { getInboxIdentifier, searchInboxes } from 'dashboard/helper/inbox';
import PageHeader from 'next/kit/PageHeader.vue';
import SectionCard from 'next/kit/SectionCard.vue';
import StatusPill from 'next/kit/StatusPill.vue';
import EmptyState from 'next/kit/EmptyState.vue';
import Button from 'next/button/Button.vue';
import ChannelIcon from 'next/icon/ChannelIcon.vue';
import Icon from 'next/icon/Icon.vue';
import ChannelName from './components/ChannelName.vue';
import { channelHealth, CHANNEL_STATES } from 'next/Channels/channelHealth';

const { t } = useI18n();
const store = useStore();
const inboxes = useMapGetter('inboxes/getInboxes');
const loading = ref(true);
const error = ref(false);
const query = ref('');
const channels = computed(() =>
  inboxes.value
    .map(inbox => ({
      ...inbox,
      channel_identifier: getInboxIdentifier(inbox),
      health: channelHealth(inbox),
    }))
    .sort((a, b) => a.name.localeCompare(b.name))
);
const filtered = computed(() =>
  searchInboxes(channels.value, query.value.trim())
);
const summaries = computed(() =>
  Object.entries(CHANNEL_STATES).map(([key, value]) => ({
    ...value,
    key,
    count: channels.value.filter(channel => channel.health.status === key)
      .length,
  }))
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
onMounted(load);
</script>

<template>
  <section class="flex w-full min-w-0 flex-col gap-5 pb-5 pt-4">
    <PageHeader
      :title="t('CHANNELS.TITLE')"
      :description="t('CHANNELS.SUBTITLE')"
    >
      <template #action>
        <router-link :to="{ name: 'settings_inbox_new' }">
          <Button :label="t('CHANNELS.ADD')" icon="i-lucide-plus" size="sm" />
        </router-link>
      </template>
    </PageHeader>
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
    <EmptyState
      v-else-if="!channels.length"
      :title="t('CHANNELS.EMPTY')"
      :description="t('CHANNELS.EMPTY_HELP')"
      icon="i-lucide-radio"
    />
    <template v-else>
      <div class="flex flex-wrap items-center gap-3">
        <div class="me-auto flex flex-wrap gap-4">
          <div
            v-for="summary in summaries"
            :key="summary.key"
            class="flex items-center gap-1.5 text-xs text-n-slate-11"
          >
            <span
              class="size-2 rounded-full"
              :class="
                summary.key === 'connected'
                  ? 'bg-n-teal-9'
                  : summary.key === 'attention'
                    ? 'bg-n-amber-9'
                    : 'bg-n-slate-9'
              "
            />
            {{ summary.count }} {{ t(summary.label) }}
          </div>
        </div>
        <label class="relative m-0 w-full sm:w-64">
          <Icon
            icon="i-lucide-search"
            class="pointer-events-none absolute start-3 top-3 size-4 text-n-slate-10"
          />
          <input
            v-model="query"
            type="search"
            :aria-label="t('CHANNELS.SEARCH')"
            :placeholder="t('CHANNELS.SEARCH')"
            class="!mb-0 !ps-9"
          />
        </label>
      </div>
      <EmptyState v-if="!filtered.length" :title="t('CHANNELS.NO_RESULTS')" />
      <div v-else class="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
        <SectionCard v-for="channel in filtered" :key="channel.id">
          <div class="flex items-center justify-between gap-2">
            <div
              class="grid size-11 shrink-0 place-items-center rounded-xl bg-n-blue-2 text-n-blue-11"
            >
              <ChannelIcon :inbox="channel" class="size-6" />
            </div>
            <StatusPill
              :status="channel.health.tone"
              :label="t(channel.health.label)"
              class="!px-2 !text-xs"
            />
          </div>
          <div class="min-w-0">
            <h2
              class="mb-1 break-words text-base font-semibold text-n-slate-12"
            >
              {{ channel.name }}
            </h2>
            <div
              class="flex min-w-0 items-center gap-1 text-xs text-n-slate-11"
            >
              <ChannelName
                :channel-type="channel.channel_type"
                :medium="channel.medium"
                :voice-enabled="channel.voice_enabled"
              />
              <div
                v-if="channel.channel_identifier"
                dir="auto"
                class="truncate"
                :title="channel.channel_identifier"
              >
                {{ channel.channel_identifier }}
              </div>
            </div>
          </div>
          <p class="m-0 min-h-10 text-sm text-n-slate-11">
            {{ t(channel.health.reason) }}
          </p>
          <div
            class="mt-auto flex items-center gap-2 border-t border-n-weak pt-3 text-xs text-n-slate-11"
          >
            <Icon icon="i-lucide-sparkles" class="size-3.5 shrink-0" />
            <span class="truncate">{{
              channel.captain_assistant?.name || t('CHANNELS.NO_AGENT')
            }}</span>
          </div>
          <router-link
            :to="{
              name: 'settings_inbox_show',
              params: { inboxId: channel.id },
            }"
          >
            <Button
              :label="
                t(
                  channel.health.status === 'attention'
                    ? 'CHANNELS.FIX'
                    : 'CHANNELS.MANAGE'
                )
              "
              :aria-label="t('CHANNELS.MANAGE_NAME', { name: channel.name })"
              :color="channel.health.status === 'attention' ? 'amber' : 'slate'"
              variant="faded"
              size="sm"
              class="w-full"
            />
          </router-link>
        </SectionCard>
      </div>
    </template>
  </section>
</template>

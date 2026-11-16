<script setup>
import { onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAdmin } from 'dashboard/composables/useAdmin';
import CaptainInboxesAPI from 'dashboard/api/captain/inboxes';
import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import TestAgentButton from 'dashboard/components-next/captain/TestAgentButton.vue';
import SectionCard from 'next/kit/SectionCard.vue';
import EmptyState from 'next/kit/EmptyState.vue';
import Button from 'next/button/Button.vue';
import ChannelIcon from 'next/icon/ChannelIcon.vue';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const { isAdmin } = useAdmin();
const inboxes = ref([]);
const loading = ref(true);
const error = ref(false);
const load = async () => {
  loading.value = true;
  error.value = false;
  try {
    const { data } = await CaptainInboxesAPI.get({
      assistantId: Number(route.params.assistantId),
    });
    inboxes.value = data.payload;
  } catch {
    error.value = true;
  } finally {
    loading.value = false;
  }
};
onMounted(load);
</script>

<template>
  <PageLayout
    :header-title="t('CHANNELS.TITLE')"
    :show-pagination-footer="false"
    :show-know-more="false"
    :is-empty="false"
  >
    <template #headerActions>
      <TestAgentButton :assistant-id="route.params.assistantId" />
      <Button
        v-if="isAdmin"
        :label="t('CHANNELS.MANAGE_ALL')"
        size="sm"
        @click="router.push({ name: 'settings_inbox_list' })"
      />
    </template>
    <template #body>
      <div class="flex flex-col gap-5 pb-8">
        <p class="m-0 text-sm text-n-slate-11">
          {{ t('CHANNELS.AGENT_CHANNELS_HELP') }}
        </p>
        <p
          v-if="loading"
          class="m-0 py-8 text-sm text-n-slate-11"
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
          v-else-if="!inboxes.length"
          :title="t('CHANNELS.NO_CONNECTED')"
          :description="t('CHANNELS.AGENT_CHANNELS_HELP')"
        />
        <div v-else class="grid gap-4 md:grid-cols-2">
          <SectionCard v-for="inbox in inboxes" :key="inbox.id">
            <div class="flex items-center gap-3">
              <ChannelIcon :inbox="inbox" class="size-6 text-n-blue-11" />
              <h2 class="m-0 text-base font-semibold text-n-slate-12">
                {{ inbox.name }}
              </h2>
            </div>
            <router-link
              v-if="isAdmin"
              :to="{
                name: 'settings_inbox_show',
                params: { inboxId: inbox.id },
              }"
            >
              <Button
                :label="t('CHANNELS.MANAGE')"
                size="sm"
                color="slate"
                variant="faded"
              />
            </router-link>
          </SectionCard>
        </div>
      </div>
    </template>
  </PageLayout>
</template>

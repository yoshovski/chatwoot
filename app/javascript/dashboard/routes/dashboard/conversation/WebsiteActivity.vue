<script setup>
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { getUnixTime } from 'date-fns';
import ConversationApi from 'dashboard/api/conversations';
import { useExactTimestamp } from 'shared/composables/useExactTimestamp';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
});

const activity = ref({});
const contactInboxId = ref(null);
const loading = ref(false);
const failed = ref(false);
const timestamp = useExactTimestamp({ showTimeZone: true });
const currentPage = computed(() => activity.value.current_page);
const recentPages = computed(() =>
  [...(activity.value.recent_pages || [])].reverse()
);
const formatTime = value => timestamp(getUnixTime(new Date(value)));

const updateActivity = data => {
  if (data.contact_inbox_id !== contactInboxId.value) return;
  const previousTime = activity.value.current_page?.last_seen_at || '';
  const nextTime = data.activity.current_page?.last_seen_at || '';
  if (nextTime >= previousTime) activity.value = data.activity;
};

const loadActivity = async () => {
  const conversationId = props.conversationId;
  loading.value = true;
  failed.value = false;
  try {
    const { data } = await ConversationApi.getWebsiteActivity(conversationId);
    if (conversationId !== props.conversationId) return;
    contactInboxId.value = data.contact_inbox_id;
    updateActivity(data);
  } catch {
    if (conversationId === props.conversationId) failed.value = true;
  } finally {
    if (conversationId === props.conversationId) loading.value = false;
  }
};

watch(
  () => props.conversationId,
  () => {
    activity.value = {};
    contactInboxId.value = null;
    loadActivity();
  },
  { immediate: true }
);
const refreshActivity = data => {
  if (data.contact_inbox_id === contactInboxId.value) loadActivity();
};
emitter.on(BUS_EVENTS.WEBSITE_ACTIVITY_UPDATED, refreshActivity);
emitter.on(BUS_EVENTS.WEBSOCKET_RECONNECT, loadActivity);
onBeforeUnmount(() => {
  emitter.off(BUS_EVENTS.WEBSITE_ACTIVITY_UPDATED, refreshActivity);
  emitter.off(BUS_EVENTS.WEBSOCKET_RECONNECT, loadActivity);
});
</script>

<template>
  <div class="px-4 py-3 border-t border-n-weak text-sm">
    <h4 class="mb-2 font-medium text-n-slate-12">
      {{ $t('CONTACT_PANEL.WEBSITE_ACTIVITY.TITLE') }}
    </h4>
    <p v-if="loading && !currentPage" class="text-n-slate-11">
      {{ $t('CONTACT_PANEL.WEBSITE_ACTIVITY.LOADING') }}
    </p>
    <button v-else-if="failed" class="text-n-brand" @click="loadActivity">
      {{ $t('CONTACT_PANEL.WEBSITE_ACTIVITY.RETRY') }}
    </button>
    <template v-else-if="currentPage">
      <p class="mb-1 text-xs text-n-slate-11">
        {{ $t('CONTACT_PANEL.WEBSITE_ACTIVITY.CURRENT_PAGE') }}
      </p>
      <a
        :href="currentPage.url"
        :title="currentPage.url"
        target="_blank"
        rel="noopener noreferrer nofollow"
        class="block text-n-brand break-words"
      >
        {{ currentPage.title || currentPage.url }}
      </a>
      <p
        v-if="currentPage.title"
        class="mt-1 text-xs text-n-slate-11 break-words"
      >
        {{ currentPage.url }}
      </p>
      <p class="mt-1 text-xs text-n-slate-11">
        {{
          $t('CONTACT_PANEL.WEBSITE_ACTIVITY.LAST_SEEN', {
            time: formatTime(currentPage.last_seen_at),
          })
        }}
      </p>
      <details v-if="recentPages.length" class="mt-3">
        <summary class="cursor-pointer text-n-slate-12">
          {{
            $t('CONTACT_PANEL.WEBSITE_ACTIVITY.HISTORY', {
              count: recentPages.length,
            })
          }}
        </summary>
        <ol class="mt-2 space-y-3">
          <li v-for="(page, index) in recentPages" :key="index">
            <a
              :href="page.url"
              :title="page.url"
              target="_blank"
              rel="noopener noreferrer nofollow"
              class="block text-n-brand break-words"
            >
              {{ page.title || page.url }}
            </a>
            <time :datetime="page.visited_at" class="text-xs text-n-slate-11">
              {{ formatTime(page.visited_at) }}
            </time>
          </li>
        </ol>
      </details>
    </template>
    <p v-else class="text-n-slate-11">
      {{ $t('CONTACT_PANEL.WEBSITE_ACTIVITY.EMPTY') }}
    </p>
  </div>
</template>

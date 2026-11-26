<script setup>
import { computed, onBeforeUnmount, ref, useId, watch } from 'vue';
import { getUnixTime } from 'date-fns';
import { dynamicTime } from 'shared/helpers/timeHelper';
import ConversationApi from 'dashboard/api/conversations';
import { useExactTimestamp } from 'shared/composables/useExactTimestamp';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';

const props = defineProps({
  compact: { type: Boolean, default: false },
  conversationId: { type: [Number, String], required: true },
});

const activity = ref({});
const contactInboxId = ref(null);
const loading = ref(false);
const failed = ref(false);
const timestamp = useExactTimestamp({ showTimeZone: true });
const currentPage = computed(() => activity.value.current_page);
const recentPages = computed(() => {
  const visits = [...(activity.value.recent_pages || [])].reverse();
  // The service includes the current visit as the last history entry.
  return props.compact && visits[0]?.url === currentPage.value?.url
    ? visits.slice(1)
    : visits;
});
const historyOpen = ref(false);
const historyId = useId();
const visitHost = page => new URL(page.url).host;
const visitLabel = page => {
  const url = new URL(page.url);
  return page.title || (url.pathname === '/' ? url.host : url.pathname);
};
const relativeTime = value => dynamicTime(getUnixTime(new Date(value)));
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
    historyOpen.value = false;
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
  <div
    v-if="!compact || loading || failed || currentPage"
    class="px-4 py-3 text-sm border-n-weak"
    :class="compact ? 'border-b' : 'border-t'"
  >
    <div class="mb-2 flex items-center justify-between gap-2">
      <h4 class="m-0 font-medium text-n-slate-12">
        {{
          $t(
            compact
              ? 'CONTACT_PANEL.WEBSITE_ACTIVITY.LAST_PAGE'
              : 'CONTACT_PANEL.WEBSITE_ACTIVITY.TITLE'
          )
        }}
      </h4>
      <button
        v-if="compact && !failed && recentPages.length"
        type="button"
        :aria-expanded="historyOpen"
        :aria-controls="historyId"
        :aria-label="
          $t('CONTACT_PANEL.WEBSITE_ACTIVITY.EARLIER_VISITS', {
            count: recentPages.length,
          })
        "
        class="inline-flex min-h-6 shrink-0 items-center gap-1 rounded px-1 text-xs text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:outline-n-brand"
        @click="historyOpen = !historyOpen"
      >
        {{
          $t('CONTACT_PANEL.WEBSITE_ACTIVITY.HISTORY_COUNT', {
            count: recentPages.length,
          })
        }}
        <span
          class="i-lucide-chevron-down size-3 transition-transform"
          :class="{ 'rotate-180': historyOpen }"
          aria-hidden="true"
        />
      </button>
    </div>
    <p v-if="loading && !currentPage" class="text-n-slate-11">
      {{ $t('CONTACT_PANEL.WEBSITE_ACTIVITY.LOADING') }}
    </p>
    <button v-else-if="failed" class="text-n-brand" @click="loadActivity">
      {{ $t('CONTACT_PANEL.WEBSITE_ACTIVITY.RETRY') }}
    </button>
    <template v-else-if="currentPage">
      <p v-if="!compact" class="mb-1 text-xs text-n-slate-11">
        {{ $t('CONTACT_PANEL.WEBSITE_ACTIVITY.CURRENT_PAGE') }}
      </p>
      <a
        :href="currentPage.url"
        :title="currentPage.url"
        target="_blank"
        rel="noopener noreferrer nofollow"
        class="min-w-0 break-words"
        :class="
          compact
            ? 'group flex items-baseline gap-1.5 font-medium text-n-slate-12 hover:text-n-brand hover:underline'
            : 'block text-n-brand'
        "
      >
        {{
          compact
            ? visitLabel(currentPage)
            : currentPage.title || currentPage.url
        }}
        <span
          v-if="compact"
          class="i-lucide-arrow-up-right size-3 shrink-0 self-center text-n-slate-10 group-hover:text-n-brand"
          aria-hidden="true"
        />
      </a>
      <p
        v-if="!compact && currentPage.title"
        class="mt-1 text-xs text-n-slate-11 break-words"
      >
        {{ currentPage.url }}
      </p>
      <div
        v-if="compact"
        class="mt-0.5 flex flex-wrap items-baseline gap-x-1.5 text-xs text-n-slate-11"
      >
        <span class="min-w-0 truncate" :title="visitHost(currentPage)">{{
          visitHost(currentPage)
        }}</span>
        <span aria-hidden="true">·</span>
        <time
          :datetime="currentPage.last_seen_at"
          :title="formatTime(currentPage.last_seen_at)"
          >{{ relativeTime(currentPage.last_seen_at) }}</time
        >
      </div>
      <p v-else class="mt-1 text-xs text-n-slate-11">
        {{
          $t('CONTACT_PANEL.WEBSITE_ACTIVITY.LAST_SEEN', {
            time: formatTime(currentPage.last_seen_at),
          })
        }}
      </p>
      <details v-if="!compact && recentPages.length" class="mt-3">
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
      <ol
        v-if="compact && recentPages.length"
        v-show="historyOpen"
        :id="historyId"
        class="m-0 mt-3 list-none space-y-2.5 border-s border-n-weak ps-3"
      >
        <li v-for="(page, index) in recentPages" :key="index" class="min-w-0">
          <a
            :href="page.url"
            :title="page.url"
            target="_blank"
            rel="noopener noreferrer nofollow"
            class="block break-words text-sm text-n-slate-12 hover:text-n-brand hover:underline"
            >{{ visitLabel(page) }}</a
          >
          <time
            :datetime="page.visited_at"
            :title="formatTime(page.visited_at)"
            class="text-xs text-n-slate-11"
            >{{ formatTime(page.visited_at) }}</time
          >
        </li>
      </ol>
    </template>
    <p v-else class="text-n-slate-11">
      {{ $t('CONTACT_PANEL.WEBSITE_ACTIVITY.EMPTY') }}
    </p>
  </div>
</template>

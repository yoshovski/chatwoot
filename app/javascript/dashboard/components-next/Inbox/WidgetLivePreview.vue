<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useDebounceFn, useEventListener } from '@vueuse/core';
import InboxesAPI from 'dashboard/api/inboxes';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

// The real widget, loaded in preview mode in an iframe and kept in sync with the settings form through postMessage.
const props = defineProps({
  inboxId: { type: Number, required: true },
  // The preview protocol's config: widgetColor, welcomeTitle, welcomeTagline, position, launcherTitle, showHome,
  // replyTime, locale, opener and the other widget settings the form edits.
  config: { type: Object, required: true },
  // Message payloads that replace the widget's sample conversation.
  messages: { type: Array, default: null },
  // AI agent test: the visitor can type, and the widget shows the AI agent typing.
  testMode: { type: Boolean, default: false },
  typing: { type: Boolean, default: false },
  // Without the stage frame, for a page that draws its own container.
  bare: { type: Boolean, default: false },
});

// Test mode: a message the visitor sent, or an answer to a suggestion or form ({ messageId, submittedValues }).
const emit = defineEmits(['send', 'submit']);

const PREVIEW_MESSAGE = 'chatoctave:preview';
const PREVIEW_READY = 'chatoctave:preview-ready';
const PREVIEW_VIEW_CHANGED = 'chatoctave:preview-view';
const PREVIEW_SEND = 'chatoctave:preview-send';
const SEND_DEBOUNCE_MS = 250;
// A fresh token is fetched this long before the current one expires.
const TOKEN_REFRESH_MARGIN_MS = 60 * 1000;

const iframe = ref(null);
const token = ref('');
const hasError = ref(false);
const isReady = ref(false);
const view = ref('home');

const previewUrl = computed(() =>
  token.value ? `/widget/preview?token=${encodeURIComponent(token.value)}` : ''
);

const send = ({ withView = true } = {}) => {
  if (!isReady.value) return;
  const payload = {
    type: PREVIEW_MESSAGE,
    config: { ...props.config, darkMode: 'light' },
  };
  if (props.testMode) {
    payload.config.testMode = true;
    payload.typing = props.typing;
  }
  if (withView) payload.view = view.value;
  if (props.messages) payload.messages = props.messages;
  // The payload goes through structured clone, so it has to be plain data.
  iframe.value.contentWindow.postMessage(
    JSON.parse(JSON.stringify(payload)),
    window.location.origin
  );
};
const sendDebounced = useDebounceFn(send, SEND_DEBOUNCE_MS);

let refreshTimer = null;

// A new token reloads the iframe; the widget asks for the current settings again once it is ready.
const fetchToken = async () => {
  clearTimeout(refreshTimer);
  try {
    const { data } = await InboxesAPI.getWidgetPreviewToken(props.inboxId);
    hasError.value = false;
    isReady.value = false;
    token.value = data.token;
    const refreshIn =
      data.expires_at * 1000 - Date.now() - TOKEN_REFRESH_MARGIN_MS;
    refreshTimer = setTimeout(fetchToken, Math.max(refreshIn, 0));
  } catch {
    hasError.value = true;
  }
};

useEventListener(window, 'message', event => {
  if (event.origin !== window.location.origin) return;
  if (event.source !== iframe.value?.contentWindow) return;

  if (event.data?.type === PREVIEW_READY) {
    isReady.value = true;
    send();
  } else if (event.data?.type === PREVIEW_VIEW_CHANGED) {
    view.value = event.data.view;
  } else if (event.data?.type === PREVIEW_SEND && props.testMode) {
    if (event.data.submitted) emit('submit', event.data.submitted);
    else emit('send', event.data.content);
  }
});

watch(
  () => props.config,
  () => sendDebounced(),
  { deep: true }
);
// A test conversation is sent at once and keeps the visitor's screen.
watch(
  () => [props.messages, props.typing],
  () => (props.testMode ? send({ withView: false }) : sendDebounced()),
  { deep: true }
);
watch(
  () => props.inboxId,
  () => fetchToken()
);

// Start over: back to the welcome screen, as a new visitor sees it.
const showHome = () => {
  view.value = 'home';
  send();
};
defineExpose({ showHome });

onMounted(fetchToken);
onBeforeUnmount(() => clearTimeout(refreshTimer));
</script>

<template>
  <section
    class="flex flex-col gap-3"
    :class="{ 'size-full': bare }"
    :aria-label="$t('INBOX_MGMT.WIDGET_PREVIEW.TITLE')"
  >
    <div v-if="!bare" class="flex items-center justify-between px-1">
      <span
        class="text-xs font-semibold uppercase tracking-wider text-n-slate-11"
      >
        {{ $t('INBOX_MGMT.WIDGET_PREVIEW.TITLE') }}
      </span>
    </div>

    <div
      :class="
        bare
          ? 'relative size-full overflow-hidden'
          : 'flex justify-center rounded-card bg-n-slate-2 p-5 outline outline-1 -outline-offset-1 outline-n-container'
      "
    >
      <div
        class="relative overflow-hidden bg-n-solid-2"
        :class="
          bare
            ? 'size-full'
            : 'w-full max-w-[24rem] h-[40rem] rounded-2xl shadow-lg'
        "
      >
        <iframe
          v-if="previewUrl"
          ref="iframe"
          :key="previewUrl"
          :src="previewUrl"
          :title="$t('INBOX_MGMT.WIDGET_PREVIEW.FRAME_TITLE')"
          class="size-full border-0"
        />
        <div
          v-if="!isReady"
          class="absolute inset-0 flex items-center justify-center bg-n-solid-2 text-center text-sm text-n-slate-11 p-6"
        >
          <span v-if="hasError">
            {{ $t('INBOX_MGMT.WIDGET_PREVIEW.ERROR') }}
          </span>
          <Spinner v-else :size="24" class="text-n-slate-10" />
        </div>
      </div>
    </div>
  </section>
</template>

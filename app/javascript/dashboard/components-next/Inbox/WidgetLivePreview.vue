<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn, useEventListener } from '@vueuse/core';
import InboxesAPI from 'dashboard/api/inboxes';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

// The real widget, loaded in preview mode in an iframe and kept in sync with the settings form through postMessage.
const props = defineProps({
  inboxId: { type: Number, required: true },
  // The preview protocol's config: widgetColor, welcomeTitle, welcomeTagline, position, launcherTitle, showHome,
  // replyTime, locale, opener and the other widget settings the form edits.
  config: { type: Object, required: true },
  // Message payloads that replace the widget's sample conversation.
  messages: { type: Array, default: null },
});

const PREVIEW_MESSAGE = 'chatoctave:preview';
const PREVIEW_READY = 'chatoctave:preview-ready';
const PREVIEW_VIEW_CHANGED = 'chatoctave:preview-view';
const SEND_DEBOUNCE_MS = 250;
// A fresh token is fetched this long before the current one expires.
const TOKEN_REFRESH_MARGIN_MS = 60 * 1000;

const { t } = useI18n();

const iframe = ref(null);
const token = ref('');
const hasError = ref(false);
const isReady = ref(false);
const view = ref('home');
const theme = ref('light');
const device = ref('desktop');

const views = computed(() => [
  { value: 'home', label: t('INBOX_MGMT.WIDGET_PREVIEW.VIEWS.HOME') },
  {
    value: 'conversation',
    label: t('INBOX_MGMT.WIDGET_PREVIEW.VIEWS.CONVERSATION'),
  },
  { value: 'launcher', label: t('INBOX_MGMT.WIDGET_PREVIEW.VIEWS.LAUNCHER') },
]);

const previewUrl = computed(() =>
  token.value ? `/widget/preview?token=${encodeURIComponent(token.value)}` : ''
);

const isDark = computed(() => theme.value === 'dark');
const isMobile = computed(() => device.value === 'mobile');

const send = () => {
  if (!isReady.value) return;
  const payload = {
    type: PREVIEW_MESSAGE,
    config: { ...props.config, darkMode: theme.value },
    view: view.value,
  };
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
  }
});

watch(() => [props.config, props.messages], sendDebounced, { deep: true });
watch([view, theme], send);
watch(
  () => props.inboxId,
  () => fetchToken()
);

onMounted(fetchToken);
onBeforeUnmount(() => clearTimeout(refreshTimer));
</script>

<template>
  <section
    class="flex flex-col gap-3"
    :aria-label="$t('INBOX_MGMT.WIDGET_PREVIEW.TITLE')"
  >
    <div class="flex flex-wrap items-center justify-between gap-2">
      <div
        class="flex items-center gap-0.5 rounded-lg bg-n-alpha-1 p-0.5"
        role="group"
        :aria-label="$t('INBOX_MGMT.WIDGET_PREVIEW.VIEW_LABEL')"
      >
        <button
          v-for="option in views"
          :key="option.value"
          type="button"
          class="rounded-md px-2.5 py-1 text-xs font-medium transition-colors"
          :class="
            view === option.value
              ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          :aria-pressed="view === option.value"
          @click="view = option.value"
        >
          {{ option.label }}
        </button>
      </div>
      <div class="flex items-center gap-1">
        <Button
          :icon="isDark ? 'i-lucide-moon' : 'i-lucide-sun'"
          :aria-label="
            isDark
              ? $t('INBOX_MGMT.WIDGET_PREVIEW.LIGHT')
              : $t('INBOX_MGMT.WIDGET_PREVIEW.DARK')
          "
          :title="
            isDark
              ? $t('INBOX_MGMT.WIDGET_PREVIEW.LIGHT')
              : $t('INBOX_MGMT.WIDGET_PREVIEW.DARK')
          "
          variant="ghost"
          color="slate"
          size="sm"
          @click="theme = isDark ? 'light' : 'dark'"
        />
        <Button
          :icon="isMobile ? 'i-lucide-smartphone' : 'i-lucide-monitor'"
          :aria-label="
            isMobile
              ? $t('INBOX_MGMT.WIDGET_PREVIEW.DESKTOP')
              : $t('INBOX_MGMT.WIDGET_PREVIEW.MOBILE')
          "
          :title="
            isMobile
              ? $t('INBOX_MGMT.WIDGET_PREVIEW.DESKTOP')
              : $t('INBOX_MGMT.WIDGET_PREVIEW.MOBILE')
          "
          variant="ghost"
          color="slate"
          size="sm"
          @click="device = isMobile ? 'desktop' : 'mobile'"
        />
      </div>
    </div>

    <div
      class="flex justify-center rounded-2xl bg-n-slate-2 p-4 outline outline-1 -outline-offset-1 outline-n-weak"
    >
      <div
        class="relative w-full h-[40rem] overflow-hidden bg-n-solid-1 shadow-lg"
        :class="
          isMobile ? 'max-w-[22.5rem] rounded-3xl' : 'max-w-[25rem] rounded-2xl'
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
          class="absolute inset-0 flex items-center justify-center bg-n-solid-1 text-center text-sm text-n-slate-11 p-6"
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

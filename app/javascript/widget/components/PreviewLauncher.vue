<script setup>
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { BUBBLE_ICON_PATH } from 'shared/constants/widgetBubble';
import { getWidgetForegroundColor } from 'shared/helpers/colorHelper';
import {
  changePreviewView,
  previewState,
  PREVIEW_VIEWS,
} from 'widget/helpers/previewMode';

// The closed launcher as the SDK draws it on a website, for the settings preview.
const router = useRouter();
const channelConfig = window.chatwootWebChannel;

const isExpanded = computed(
  () => previewState.bubbleType === 'expanded_bubble'
);
const iconColor = computed(
  () =>
    channelConfig.widgetIconColor ||
    getWidgetForegroundColor(channelConfig.widgetColor)
);
</script>

<template>
  <div
    class="flex flex-1 items-end p-5 bg-n-background"
    :class="previewState.position === 'left' ? 'justify-start' : 'justify-end'"
  >
    <button
      type="button"
      class="flex items-center gap-2.5 rounded-full bg-[var(--widget-color)] text-[var(--widget-text-color)] shadow-lg"
      :class="isExpanded ? 'h-12 px-4' : 'size-16 justify-center'"
      :aria-label="previewState.launcherTitle || $t('BUBBLE.LABEL')"
      @click="changePreviewView(router, PREVIEW_VIEWS.HOME)"
    >
      <svg viewBox="0 0 240 240" class="size-6" aria-hidden="true">
        <path :d="BUBBLE_ICON_PATH" :fill="iconColor" />
      </svg>
      <span v-if="isExpanded" class="text-base font-medium">
        {{ previewState.launcherTitle || $t('BUBBLE.LABEL') }}
      </span>
    </button>
  </div>
</template>

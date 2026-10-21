<script setup>
import { useI18n } from 'vue-i18n';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

defineProps({
  name: {
    type: String,
    default: '',
  },
  avatarUrl: {
    type: String,
    default: '',
  },
  label: {
    type: String,
    default: '',
  },
});

const { t } = useI18n();
</script>

<template>
  <div class="flex flex-col gap-2">
    <span class="text-xs font-medium text-n-slate-11">
      {{ label || t('CAPTAIN.ASSISTANTS.SETTINGS.PREVIEW.LABEL') }}
    </span>
    <div
      class="overflow-hidden rounded-2xl outline outline-1 outline-n-weak bg-n-solid-1 shadow-sm"
      aria-hidden="true"
    >
      <div class="flex items-center gap-3 px-4 py-3 bg-n-brand">
        <Avatar
          :src="avatarUrl"
          :name="name"
          :size="32"
          icon-name="i-lucide-bot-message-square"
          rounded-full
        />
        <div class="flex flex-col min-w-0">
          <span class="text-sm font-semibold text-white truncate">
            {{ name }}
          </span>
          <span class="text-xs text-white/80">
            {{ t('CAPTAIN.ASSISTANTS.SETTINGS.PREVIEW.AI_AGENT') }}
          </span>
        </div>
      </div>
      <div class="flex flex-col gap-2.5 p-4 bg-n-slate-2 min-h-40">
        <slot>
          <p class="preview-bubble preview-bubble--agent">
            {{
              t('CAPTAIN.ASSISTANTS.SETTINGS.IDENTITY.PREVIEW_GREETING', {
                name,
              })
            }}
          </p>
          <p class="preview-bubble preview-bubble--customer">
            {{ t('CAPTAIN.ASSISTANTS.SETTINGS.IDENTITY.PREVIEW_QUESTION') }}
          </p>
        </slot>
      </div>
      <div
        class="flex items-center justify-between gap-2 px-4 py-2.5 text-xs border-t border-n-weak text-n-slate-10"
      >
        {{ t('CAPTAIN.ASSISTANTS.SETTINGS.PREVIEW.COMPOSER') }}
        <span class="i-lucide-send-horizontal size-4" />
      </div>
    </div>
  </div>
</template>

<style scoped>
:deep(.preview-bubble) {
  @apply max-w-[88%] mb-0 px-3 py-2 text-sm rounded-xl whitespace-pre-line break-words;
}

:deep(.preview-bubble--agent) {
  @apply self-start bg-n-solid-1 text-n-slate-12 outline outline-1 outline-n-weak ltr:rounded-bl-sm rtl:rounded-br-sm;
}

:deep(.preview-bubble--customer) {
  @apply self-end text-white bg-n-brand ltr:rounded-br-sm rtl:rounded-bl-sm;
}
</style>

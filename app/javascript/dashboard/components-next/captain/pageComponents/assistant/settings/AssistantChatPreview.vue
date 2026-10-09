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
});

const { t } = useI18n();
</script>

<template>
  <div class="flex flex-col gap-2">
    <span class="text-xs text-n-slate-11">
      {{ t('CAPTAIN.ASSISTANTS.SETTINGS.IDENTITY.PREVIEW_LABEL') }}
    </span>
    <div
      class="overflow-hidden rounded-2xl outline outline-1 outline-n-weak bg-n-solid-1"
      aria-hidden="true"
    >
      <div class="flex items-center gap-3 px-4 py-3.5 bg-n-brand">
        <Avatar
          :src="avatarUrl"
          :name="name"
          :size="36"
          icon-name="i-lucide-bot-message-square"
          rounded-full
        />
        <div class="flex flex-col min-w-0">
          <span class="text-sm font-semibold text-white truncate">
            {{ name }}
          </span>
          <span class="text-xs text-white/80">
            {{ t('CAPTAIN.ASSISTANTS.SETTINGS.IDENTITY.PREVIEW_SUBTITLE') }}
          </span>
        </div>
      </div>
      <div class="flex flex-col gap-2.5 p-4 bg-n-slate-2 min-h-36">
        <p
          class="self-start max-w-[85%] mb-0 px-3 py-2 text-sm rounded-xl ltr:rounded-bl-sm rtl:rounded-br-sm bg-n-solid-1 text-n-slate-12 outline outline-1 outline-n-weak"
        >
          {{
            t('CAPTAIN.ASSISTANTS.SETTINGS.IDENTITY.PREVIEW_GREETING', { name })
          }}
        </p>
        <p
          class="self-end max-w-[85%] mb-0 px-3 py-2 text-sm text-white rounded-xl ltr:rounded-br-sm rtl:rounded-bl-sm bg-n-brand"
        >
          {{ t('CAPTAIN.ASSISTANTS.SETTINGS.IDENTITY.PREVIEW_QUESTION') }}
        </p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  assistant: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const HOURS_KEYS = {
  always: 'ALWAYS',
  business_hours: 'BUSINESS_HOURS',
  outside_business_hours: 'OUTSIDE_BUSINESS_HOURS',
};

const summary = computed(() => {
  const config = props.assistant.config || {};
  const hoursKey = HOURS_KEYS[config.response_window] || HOURS_KEYS.always;
  return [
    config.product_name &&
      t('CAPTAIN.ASSISTANTS.SETTINGS.PROFILE.WORKS_FOR', {
        product: config.product_name,
      }),
    t(`CAPTAIN.ASSISTANTS.SETTINGS.PROFILE.HOURS.${hoursKey}`),
  ]
    .filter(Boolean)
    .join(' · ');
});

const openPlayground = () => {
  router.push({
    name: 'captain_assistants_playground_index',
    params: {
      accountId: route.params.accountId,
      assistantId: route.params.assistantId,
    },
  });
};
</script>

<template>
  <div
    class="flex flex-wrap items-center gap-4 px-5 py-4 rounded-xl outline outline-1 outline-n-weak bg-n-solid-1"
  >
    <Avatar
      :src="assistant.avatar_url"
      :name="assistant.name"
      :size="48"
      icon-name="i-lucide-bot-message-square"
      rounded-full
    />
    <div class="flex flex-col flex-1 min-w-0 gap-0.5">
      <span class="text-base font-semibold truncate text-n-slate-12">
        {{ assistant.name }}
      </span>
      <span class="text-sm text-n-slate-11">{{ summary }}</span>
    </div>
    <Button
      :label="
        t('CAPTAIN.ASSISTANTS.SETTINGS.PROFILE.CHAT_WITH', {
          name: assistant.name,
        })
      "
      icon="i-lucide-message-circle"
      color="slate"
      variant="faded"
      size="sm"
      @click="openPlayground"
    />
  </div>
</template>

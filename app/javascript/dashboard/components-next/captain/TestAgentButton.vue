<script setup>
import { useRoute } from 'vue-router';
import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  assistantId: {
    type: [Number, String],
    default: null,
  },
});

const route = useRoute();
</script>

<template>
  <router-link
    v-if="assistantId"
    :to="{
      name: 'captain_assistants_playground_index',
      params: { accountId: route.params.accountId, assistantId },
    }"
  >
    <Button
      :label="$t('PLATFORM_NAV.TEST_AGENT')"
      icon="i-lucide-play"
      variant="outline"
      color="slate"
      size="sm"
    />
  </router-link>
</template>

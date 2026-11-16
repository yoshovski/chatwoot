<script setup>
import EmptyState from 'dashboard/components-next/kit/EmptyState.vue';
import Button from 'next/button/Button.vue';

defineProps({
  title: { type: String, required: true },
  stale: { type: Boolean, default: false },
});
defineEmits(['retry']);
</script>

<template>
  <EmptyState
    :title="title"
    :description="
      $t(
        stale ? 'CAPTAIN.KNOWLEDGE_LOAD.STALE' : 'CAPTAIN.KNOWLEDGE_LOAD.FAILED'
      )
    "
    tone="error"
    icon="i-lucide-circle-alert"
  >
    <Button
      :label="$t('PLATFORM_NAV.RETRY')"
      size="sm"
      @click="$emit('retry')"
    />
  </EmptyState>
</template>

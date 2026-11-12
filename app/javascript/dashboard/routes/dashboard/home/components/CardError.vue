<script setup>
import Button from 'dashboard/components-next/button/Button.vue';
import EmptyState from 'dashboard/components-next/kit/EmptyState.vue';

const emit = defineEmits(['retry']);
</script>

<template>
  <EmptyState
    tone="error"
    icon="i-lucide-circle-alert"
    :title="$t('HOME.V2.CARD_ERROR')"
  >
    <Button
      :label="$t('HOME.RETRY')"
      size="sm"
      variant="faded"
      color="slate"
      @click="emit('retry')"
    />
  </EmptyState>
</template>

<script setup>
import EmptyState from 'dashboard/components-next/kit/EmptyState.vue';
import Button from 'next/button/Button.vue';
import Policy from 'dashboard/components/policy.vue';

defineEmits(['click']);
</script>

<template>
  <EmptyState
    :title="$t('CAPTAIN.RESPONSES.EMPTY_STATE.TITLE')"
    :description="$t('CAPTAIN.RESPONSES.EMPTY_STATE.SUBTITLE')"
    icon="i-lucide-book-open"
  >
    <Policy :permissions="['administrator']">
      <Button
        :label="$t('CAPTAIN.RESPONSES.ADD_NEW')"
        icon="i-lucide-plus"
        @click="$emit('click')"
      />
    </Policy>
  </EmptyState>
</template>

<script setup>
import EmptyState from 'dashboard/components-next/kit/EmptyState.vue';

// Design step only: the other tabs follow the Overview layout Stefan picks.
</script>

<template>
  <EmptyState
    icon="i-lucide-chart-column"
    :title="$t('ANALYTICS.PENDING.TITLE')"
    :description="$t('ANALYTICS.PENDING.DESCRIPTION')"
  />
</template>

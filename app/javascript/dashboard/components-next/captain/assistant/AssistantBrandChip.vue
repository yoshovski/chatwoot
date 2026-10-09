<script setup>
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
</script>

<template>
  <span
    class="inline-flex items-center px-1.5 py-0.5 text-xs font-medium rounded-md shrink-0 bg-n-alpha-2 text-n-slate-11"
  >
    {{ t('CAPTAIN.ASSISTANTS.AI_AGENT_CHIP') }}
  </span>
</template>

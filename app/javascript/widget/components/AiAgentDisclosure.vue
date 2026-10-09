<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();

const assistantName = computed(
  () => window.chatwootWebChannel?.captainAssistant?.name
);
</script>

<template>
  <p
    v-if="assistantName"
    class="flex items-center gap-1 m-0 text-xs leading-4 text-n-slate-11"
  >
    <span class="i-lucide-sparkles size-3 shrink-0" aria-hidden="true" />
    <span class="truncate">
      {{ t('AI_AGENT_HEADER.LABEL', { name: assistantName }) }}
    </span>
  </p>
</template>

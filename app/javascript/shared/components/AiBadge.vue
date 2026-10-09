<script setup>
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
</script>

<template>
  <span
    role="img"
    :title="t('AI_BADGE.TITLE')"
    :aria-label="t('AI_BADGE.TITLE')"
    class="inline-flex items-center px-1 text-[10px] font-semibold leading-4 rounded shrink-0 bg-n-alpha-2 text-n-slate-11"
  >
    {{ t('AI_BADGE.LABEL') }}
  </span>
</template>

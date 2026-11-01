<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

// The installation check's answer, shared by the guided setup and the website inbox settings.
const props = defineProps({
  result: { type: String, required: true },
  site: { type: String, default: '' },
});

const RESULT_STYLE = {
  installed: { icon: 'i-lucide-circle-check', tone: 'text-n-teal-10' },
  script_found: { icon: 'i-lucide-clock', tone: 'text-n-amber-10' },
  not_found: { icon: 'i-lucide-circle-alert', tone: 'text-n-amber-10' },
  unreachable: { icon: 'i-lucide-circle-x', tone: 'text-n-ruby-10' },
  error: { icon: 'i-lucide-circle-x', tone: 'text-n-ruby-10' },
};

const { t } = useI18n();

const text = computed(() => {
  const params = { site: props.site };
  return {
    installed: t('HOME.GUIDED.INSTALL.RESULT.INSTALLED', params),
    script_found: t('HOME.GUIDED.INSTALL.RESULT.SCRIPT_FOUND', params),
    not_found: t('HOME.GUIDED.INSTALL.RESULT.NOT_FOUND', params),
    unreachable: t('HOME.GUIDED.INSTALL.RESULT.UNREACHABLE', params),
    error: t('HOME.GUIDED.INSTALL.RESULT.ERROR', params),
  }[props.result];
});
</script>

<template>
  <p role="status" class="mb-0 flex items-start gap-2 text-sm text-n-slate-11">
    <Icon
      :icon="RESULT_STYLE[result].icon"
      class="mt-0.5 size-4 shrink-0"
      :class="RESULT_STYLE[result].tone"
    />
    {{ text }}
  </p>
</template>

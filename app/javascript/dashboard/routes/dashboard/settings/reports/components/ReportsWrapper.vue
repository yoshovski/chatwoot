<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { RouterLink, RouterView, useRoute } from 'vue-router';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { MORE_REPORTS } from '../moreReports';

// The upstream report pages, kept as they are under Analytics → More reports, with a way between them.
const { t } = useI18n();
const route = useRoute();

const labels = computed(() => ({
  LIVE: t('ANALYTICS.MORE.LIVE'),
  CONVERSATIONS: t('ANALYTICS.MORE.CONVERSATIONS'),
  AGENTS: t('ANALYTICS.MORE.AGENTS'),
  LABELS: t('ANALYTICS.MORE.LABELS'),
  INBOXES: t('ANALYTICS.MORE.INBOXES'),
  TEAMS: t('ANALYTICS.MORE.TEAMS'),
  RATING: t('ANALYTICS.MORE.RATING'),
  TARGETS: t('ANALYTICS.MORE.TARGETS'),
  AI_AGENT: t('ANALYTICS.MORE.AI_AGENT'),
}));

const links = computed(() =>
  MORE_REPORTS.map(report => ({
    ...report,
    label: labels.value[report.key],
    active: [report.name, ...report.activeOn].includes(route.name),
  }))
);
</script>

<template>
  <div class="overflow-auto bg-n-surface-1 w-full px-6">
    <div class="max-w-5xl mx-auto pb-12">
      <nav
        :aria-label="t('ANALYTICS.MORE.LABEL')"
        class="flex items-center gap-1 overflow-x-auto border-b border-n-weak pt-4"
      >
        <RouterLink
          :to="{ name: 'analytics_reports' }"
          class="me-2 inline-flex shrink-0 items-center gap-1 py-2 text-sm font-medium text-n-blue-11"
        >
          <Icon icon="i-lucide-arrow-left" class="size-4" />
          {{ t('ANALYTICS.MORE.BACK') }}
        </RouterLink>
        <RouterLink
          v-for="link in links"
          :key="link.name"
          :to="{ name: link.name }"
          class="-mb-px shrink-0 border-b-2 px-2.5 py-2 text-sm"
          :class="
            link.active
              ? 'border-n-blue-9 font-medium text-n-slate-12'
              : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
          "
          :aria-current="link.active ? 'page' : undefined"
        >
          {{ link.label }}
        </RouterLink>
      </nav>
      <RouterView />
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { RouterLink } from 'vue-router';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  MORE_REPORTS,
  MORE_REPORT_GROUPS,
} from '../settings/reports/moreReports';

// Every detailed report, grouped by the question it answers, each with one line on what you find there.
const { t } = useI18n();

const groupTitles = computed(() => ({
  NOW: t('ANALYTICS.REPORTS.GROUPS.NOW'),
  WHO: t('ANALYTICS.REPORTS.GROUPS.WHO'),
  QUALITY: t('ANALYTICS.REPORTS.GROUPS.QUALITY'),
}));

const reports = computed(() => ({
  LIVE: [t('ANALYTICS.MORE.LIVE'), t('ANALYTICS.REPORTS.ITEMS.LIVE')],
  CONVERSATIONS: [
    t('ANALYTICS.MORE.CONVERSATIONS'),
    t('ANALYTICS.REPORTS.ITEMS.CONVERSATIONS'),
  ],
  AGENTS: [t('ANALYTICS.MORE.AGENTS'), t('ANALYTICS.REPORTS.ITEMS.AGENTS')],
  TEAMS: [t('ANALYTICS.MORE.TEAMS'), t('ANALYTICS.REPORTS.ITEMS.TEAMS')],
  INBOXES: [t('ANALYTICS.MORE.INBOXES'), t('ANALYTICS.REPORTS.ITEMS.INBOXES')],
  LABELS: [t('ANALYTICS.MORE.LABELS'), t('ANALYTICS.REPORTS.ITEMS.LABELS')],
  AI_AGENT: [
    t('ANALYTICS.MORE.AI_AGENT'),
    t('ANALYTICS.REPORTS.ITEMS.AI_AGENT'),
  ],
  RATING: [t('ANALYTICS.MORE.RATING'), t('ANALYTICS.REPORTS.ITEMS.RATING')],
  TARGETS: [t('ANALYTICS.MORE.TARGETS'), t('ANALYTICS.REPORTS.ITEMS.TARGETS')],
}));

const groups = computed(() =>
  MORE_REPORT_GROUPS.map(group => ({
    key: group,
    title: groupTitles.value[group],
    reports: MORE_REPORTS.filter(report => report.group === group).map(
      report => {
        const [title, description] = reports.value[report.key];
        return { ...report, title, description };
      }
    ),
  }))
);
</script>

<template>
  <div class="flex flex-col gap-6">
    <section
      v-for="group in groups"
      :key="group.key"
      class="flex flex-col gap-3"
      :aria-labelledby="`reports-${group.key}`"
    >
      <h2
        :id="`reports-${group.key}`"
        class="mb-0 text-xs font-semibold uppercase tracking-wide text-n-slate-11"
      >
        {{ group.title }}
      </h2>
      <ul
        class="m-0 grid list-none grid-cols-1 gap-3 p-0 sm:grid-cols-2 lg:grid-cols-3"
      >
        <li v-for="report in group.reports" :key="report.key" class="flex">
          <RouterLink
            :to="{ name: report.name }"
            class="group flex w-full items-start gap-3 rounded-card bg-n-solid-2 p-4 shadow-card outline outline-1 -outline-offset-1 outline-n-container hover:outline-n-blue-7 focus-visible:outline-2 focus-visible:outline-n-blue-9"
          >
            <span
              class="grid size-9 shrink-0 place-items-center rounded-lg bg-n-blue-3 text-n-blue-11"
            >
              <Icon :icon="report.icon" class="size-4" />
            </span>
            <span class="flex min-w-0 flex-1 flex-col gap-0.5">
              <span class="text-sm font-semibold text-n-slate-12">
                {{ report.title }}
              </span>
              <span class="text-xs leading-5 text-n-slate-11">
                {{ report.description }}
              </span>
            </span>
            <Icon
              icon="i-lucide-arrow-right"
              class="mt-0.5 size-4 shrink-0 text-n-slate-9 group-hover:text-n-blue-11"
            />
          </RouterLink>
        </li>
      </ul>
    </section>
  </div>
</template>

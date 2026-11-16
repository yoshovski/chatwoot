<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import PageFrame from 'next/kit/PageFrame.vue';
import PageHeader from 'next/kit/PageHeader.vue';
import SectionCard from 'next/kit/SectionCard.vue';
import SearchField from 'next/kit/SearchField.vue';
import EmptyState from 'next/kit/EmptyState.vue';
import Icon from 'next/icon/Icon.vue';
import { useSettingsSections } from './useSettingsSections';

// Settings open here: one search field, then a card per section listing its pages.
const { t } = useI18n();
const sections = useSettingsSections();
const query = ref('');

const terms = computed(() =>
  query.value.trim().toLowerCase().split(/\s+/).filter(Boolean)
);

// Every word of the query must appear in the page's label, hint or keywords.
const matches = computed(() =>
  sections.value.flatMap(section =>
    section.pages
      .filter(page => {
        const words =
          `${page.label} ${page.hint} ${page.keywords}`.toLowerCase();
        return terms.value.every(term => words.includes(term));
      })
      .map(page => ({ ...page, section: section.title }))
  )
);
</script>

<template>
  <PageFrame>
    <template #header>
      <PageHeader
        :title="t('SETTINGS_HOME.TITLE')"
        :description="t('SETTINGS_HOME.SUBTITLE')"
      />
    </template>

    <SearchField
      v-model="query"
      large
      :placeholder="t('SETTINGS_HOME.SEARCH_PLACEHOLDER')"
    />

    <template v-if="terms.length">
      <EmptyState
        v-if="!matches.length"
        icon="i-lucide-search-x"
        :title="t('SETTINGS_HOME.NO_RESULTS', { query: query.trim() })"
      />
      <SectionCard v-else>
        <ul class="m-0 flex list-none flex-col divide-y divide-n-weak p-0">
          <li v-for="page in matches" :key="page.key">
            <router-link
              :to="page.to"
              class="-mx-2 flex items-center gap-3 rounded-lg px-2 py-2.5 hover:bg-n-alpha-1"
            >
              <span
                class="grid size-9 shrink-0 place-items-center rounded-xl bg-n-blue-3 text-n-blue-11"
              >
                <Icon :icon="page.icon" class="size-4" />
              </span>
              <span class="me-auto flex min-w-0 flex-col">
                <span class="truncate text-sm font-medium text-n-slate-12">
                  {{ page.label }}
                </span>
                <span class="truncate text-xs text-n-slate-11">
                  {{ page.hint }}
                </span>
              </span>
              <span class="hidden shrink-0 text-xs text-n-slate-10 sm:inline">
                {{ page.section }}
              </span>
            </router-link>
          </li>
        </ul>
      </SectionCard>
    </template>

    <div v-else class="grid grid-cols-1 gap-5 md:grid-cols-2 lg:grid-cols-3">
      <SectionCard v-for="section in sections" :key="section.key">
        <div class="flex items-start gap-3">
          <span
            class="grid size-10 shrink-0 place-items-center rounded-xl bg-n-blue-3 text-n-blue-11"
          >
            <Icon :icon="section.icon" class="size-5" />
          </span>
          <div class="flex min-w-0 flex-col gap-0.5">
            <h2
              class="mb-0 font-display text-base font-semibold tracking-display text-n-slate-12"
            >
              {{ section.title }}
            </h2>
            <p class="mb-0 text-sm text-n-slate-11">{{ section.hint }}</p>
          </div>
        </div>
        <ul class="mb-0 flex list-none flex-col p-0">
          <li v-for="page in section.pages" :key="page.key">
            <router-link
              :to="page.to"
              class="-mx-2 flex items-center gap-2 rounded-lg px-2 py-2 text-sm text-n-slate-12 hover:bg-n-alpha-1"
            >
              <span class="me-auto truncate">{{ page.label }}</span>
              <Icon
                icon="i-lucide-chevron-right"
                class="size-4 shrink-0 text-n-slate-10 rtl:rotate-180"
              />
            </router-link>
          </li>
        </ul>
      </SectionCard>
    </div>
  </PageFrame>
</template>

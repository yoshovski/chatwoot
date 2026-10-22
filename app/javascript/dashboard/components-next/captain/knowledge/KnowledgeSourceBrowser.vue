<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import api from 'dashboard/api/captain/knowledgeSources';
import Button from 'next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import { hostOf, sourceForHost } from './websiteSourceHosts';

const props = defineProps({
  assistantId: { type: Number, required: true },
  // Administrators can choose which discovered pages become knowledge.
  canManage: { type: Boolean, default: false },
});
const emit = defineEmits(['loaded', 'manage']);
// 'all', 'pdf', 'text', or a website host.
const source = defineModel('source', { type: String, default: 'all' });
const { t } = useI18n();
const request = useAbortableRequest();
const sourcesRequest = useAbortableRequest();
const sections = ref([]);
const websiteSources = ref([]);
const error = ref(false);
const menuOpen = ref(false);

const FILE_SOURCES = [
  {
    value: 'pdf',
    labelKey: 'KNOWLEDGE_LIST.SOURCE.FILES',
    icon: 'i-lucide-file-text',
  },
  {
    value: 'text',
    labelKey: 'KNOWLEDGE_LIST.SOURCE.TEXT',
    icon: 'i-lucide-align-left',
  },
];

const websites = computed(() => {
  const counts = new Map();
  sections.value.forEach(item => {
    const host = item.key.split('/')[0];
    if (host !== 'files')
      counts.set(host, (counts.get(host) || 0) + item.count);
  });
  const imported = [...counts].map(([host, count]) => ({
    host,
    count,
    source: sourceForHost(websiteSources.value, host),
  }));
  // Discovered websites without imported pages yet still need a way in.
  const pending = websiteSources.value
    .filter(
      item =>
        !imported.some(
          site => site.source?.id === item.id || site.host === hostOf(item.url)
        )
    )
    .map(item => ({ host: hostOf(item.url), count: 0, source: item }));
  return [...imported, ...pending];
});

const activeSite = computed(() =>
  websites.value.find(site => site.host === source.value)
);
const selectedLabel = computed(() => {
  const file = FILE_SOURCES.find(item => item.value === source.value);
  if (file) return t(file.labelKey);
  return activeSite.value?.host || t('PLATFORM_NAV.ALL_SOURCES');
});
const menuSections = computed(() => [
  {
    items: [
      {
        label: t('PLATFORM_NAV.ALL_SOURCES'),
        value: 'all',
        icon: 'i-lucide-files',
        isSelected: source.value === 'all',
      },
    ],
  },
  {
    title: t('KNOWLEDGE_LIST.SOURCE.WEBSITES'),
    items: websites.value.map(site => ({
      label: t('KNOWLEDGE_LIST.SOURCE.WEBSITE_COUNT', {
        host: site.host,
        count: site.count,
      }),
      value: site.host,
      icon: 'i-lucide-globe',
      isSelected: source.value === site.host,
    })),
  },
  {
    title: t('KNOWLEDGE_LIST.SOURCE.OTHER'),
    items: FILE_SOURCES.map(item => ({
      label: t(item.labelKey),
      value: item.value,
      icon: item.icon,
      isSelected: source.value === item.value,
    })),
  },
]);
const siteSummary = computed(() => {
  const site = activeSite.value;
  if (site.count) return t('PLATFORM_NAV.PAGES', { count: site.count });
  return ['pending', 'discovering'].includes(site.source?.status)
    ? t('PLATFORM_NAV.WEBSITE_DISCOVERING')
    : t('PLATFORM_NAV.WEBSITE_NOT_ADDED');
});

const pick = ({ value }) => {
  menuOpen.value = false;
  source.value = value;
};

const loadSources = async () => {
  try {
    const response = await sourcesRequest.run(signal =>
      api.list(props.assistantId, signal)
    );
    if (response) websiteSources.value = response.data;
  } catch {
    websiteSources.value = [];
  }
};
const load = async () => {
  error.value = false;
  loadSources();
  try {
    const response = await request.run(signal =>
      api.sections(props.assistantId, signal)
    );
    if (!response) return;
    sections.value = response.data.sections;
    emit('loaded', sections.value.length > 0);
  } catch {
    error.value = true;
  }
};
watch(
  () => props.assistantId,
  () => {
    sections.value = [];
    websiteSources.value = [];
    emit('loaded', false);
    load();
  },
  { immediate: true }
);
defineExpose({ load });
</script>

<template>
  <div class="flex flex-col gap-3 mb-3">
    <div class="flex flex-wrap items-center gap-2">
      <slot />
      <div v-on-click-outside="() => (menuOpen = false)" class="relative">
        <Button
          icon="i-lucide-layers"
          slate
          size="sm"
          :class="{ 'bg-n-slate-9/10': menuOpen }"
          @click="menuOpen = !menuOpen"
        >
          <span class="min-w-0 truncate max-w-56">{{ selectedLabel }}</span>
          <Icon icon="i-lucide-chevron-down" class="shrink-0 size-4" />
        </Button>
        <DropdownMenu
          v-if="menuOpen"
          :menu-sections="menuSections"
          class="z-30 mt-2 top-full min-w-72 max-h-96 overflow-y-auto ltr:left-0 rtl:right-0"
          @action="pick"
        />
      </div>
      <slot name="filters" />
    </div>
    <p
      v-if="error"
      class="flex items-center gap-3 m-0 text-sm text-n-ruby-11"
      role="alert"
    >
      {{ t('PLATFORM_NAV.LOAD_ERROR') }}
      <Button
        :label="t('PLATFORM_NAV.RETRY')"
        variant="link"
        size="sm"
        @click="load"
      />
    </p>
    <div
      v-if="activeSite"
      class="flex flex-wrap items-center gap-3 px-4 py-3 border rounded-xl border-n-brand/20 bg-n-brand/5"
    >
      <span
        class="flex items-center justify-center rounded-lg size-8 shrink-0 bg-n-brand/10 text-n-brand"
        aria-hidden="true"
      >
        <span class="i-lucide-globe size-4" />
      </span>
      <div class="flex flex-col flex-1 min-w-0">
        <span class="text-sm font-semibold truncate text-n-slate-12">
          {{ activeSite.host }}
        </span>
        <span class="text-xs text-n-slate-11">{{ siteSummary }}</span>
      </div>
      <Button
        v-if="canManage && activeSite.source"
        v-tooltip.top="t('PLATFORM_NAV.CHOOSE_PAGES_HINT')"
        size="sm"
        variant="outline"
        color="slate"
        icon="i-lucide-list-checks"
        :label="t('PLATFORM_NAV.MANAGE_PAGES')"
        @click="emit('manage', activeSite.source)"
      />
      <Button
        v-tooltip.top="t('PLATFORM_NAV.CLEAR_FILTERS')"
        :aria-label="t('PLATFORM_NAV.CLEAR_FILTERS')"
        icon="i-lucide-x"
        size="sm"
        variant="ghost"
        color="slate"
        @click="source = 'all'"
      />
    </div>
  </div>
</template>

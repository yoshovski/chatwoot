<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import api from 'dashboard/api/captain/knowledgeSources';
import Button from 'next/button/Button.vue';
import { hostOf, sourceForHost } from './websiteSourceHosts';

const props = defineProps({
  assistantId: { type: Number, required: true },
  // Administrators can choose which discovered pages become knowledge.
  canManage: { type: Boolean, default: false },
});
const emit = defineEmits(['loaded', 'manage']);
const website = defineModel('website', { type: String, default: null });
const section = defineModel('section', { type: String, default: null });
const { t } = useI18n();
const request = useAbortableRequest();
const sourcesRequest = useAbortableRequest();
const sections = ref([]);
const websiteSources = ref([]);
const error = ref(false);

const STATE_BARS = [
  ['ready', 'bg-n-teal-9'],
  ['syncing', 'bg-n-amber-9'],
  ['failed', 'bg-n-ruby-9'],
  ['paused', 'bg-n-slate-7'],
];

const websites = computed(() => {
  const grouped = new Map();
  sections.value.forEach(item => {
    const host = item.key.split('/')[0];
    const group = grouped.get(host) || {
      host,
      count: 0,
      ready: 0,
      syncing: 0,
      failed: 0,
      paused: 0,
    };
    group.count += item.count;
    STATE_BARS.forEach(([state]) => {
      group[state] += item[state] || 0;
    });
    grouped.set(host, group);
  });
  return [...grouped.values()].map(group => ({
    ...group,
    source: sourceForHost(websiteSources.value, group.host),
  }));
});
// Discovered websites without imported pages yet still need a way in.
const pendingSources = computed(() =>
  websiteSources.value.filter(
    source =>
      !websites.value.some(site => site.source?.id === source.id) &&
      !websites.value.some(site => site.host === hostOf(source.url))
  )
);
const hasCards = computed(
  () => websites.value.length > 0 || pendingSources.value.length > 0
);
const folders = computed(() =>
  sections.value.filter(item => item.key.startsWith(`${website.value}/`))
);
const activeSource = computed(() =>
  website.value && website.value !== '*'
    ? sourceForHost(websiteSources.value, website.value)
    : null
);
const label = host => (host === 'files' ? t('PLATFORM_NAV.FILES') : host);
const segments = site =>
  STATE_BARS.filter(([state]) => site[state] > 0).map(([state, color]) => ({
    state,
    color,
    width: `${(site[state] / site.count) * 100}%`,
  }));
const health = site => {
  if (site.failed) {
    return {
      text: t('PLATFORM_NAV.FAILED_PAGES', { count: site.failed }),
      tone: 'text-n-ruby-11',
    };
  }
  if (site.syncing) {
    return {
      text: t('PLATFORM_NAV.UPDATING_PAGES', { count: site.syncing }),
      tone: 'text-n-amber-11',
    };
  }
  return { text: t('PLATFORM_NAV.NO_FAILURES'), tone: 'text-n-slate-10' };
};
const pendingText = source =>
  ['pending', 'discovering'].includes(source.status)
    ? t('PLATFORM_NAV.WEBSITE_DISCOVERING')
    : t('PLATFORM_NAV.WEBSITE_NOT_ADDED');

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
const browse = host => {
  section.value = null;
  website.value = host;
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
  <div class="mb-4">
    <div
      v-if="error"
      class="flex items-center gap-3 py-3 text-sm text-n-ruby-11"
      role="alert"
    >
      {{ t('PLATFORM_NAV.LOAD_ERROR') }}
      <Button
        :label="t('PLATFORM_NAV.RETRY')"
        variant="link"
        size="sm"
        @click="load"
      />
    </div>
    <div v-if="website" class="mb-4 flex flex-wrap items-center gap-3">
      <Button
        :label="t('PLATFORM_NAV.ALL_WEBSITES')"
        variant="link"
        size="sm"
        @click="browse(null)"
      />
      <span
        class="i-lucide-chevron-right size-4 text-n-slate-10 rtl:rotate-180"
        aria-hidden="true"
      />
      <span class="text-sm font-medium text-n-slate-12">
        {{ website === '*' ? t('PLATFORM_NAV.ALL_SOURCES') : label(website) }}
      </span>
      <Button
        v-if="canManage && activeSource"
        size="xs"
        variant="faded"
        icon="i-lucide-list-checks"
        :label="t('PLATFORM_NAV.CHOOSE_PAGES')"
        @click="emit('manage', activeSource)"
      />
      <div
        v-if="folders.length"
        class="ms-auto flex items-center gap-2 text-sm text-n-slate-11"
      >
        <div
          class="relative flex items-center rounded-lg border border-n-weak bg-n-solid-1 px-2.5 py-1.5 text-sm text-n-slate-12 hover:bg-n-alpha-1 hover:border-n-slate-6 transition-all shadow-xs"
        >
          <span
            class="i-lucide-folder size-4 text-n-slate-10 shrink-0 me-1.5"
            aria-hidden="true"
          />
          <select
            :value="section || ''"
            :aria-label="t('PLATFORM_NAV.FILTER_BY_FOLDER')"
            class="appearance-none bg-transparent pe-6 text-sm font-medium text-n-slate-12 focus:outline-none cursor-pointer"
            @change="section = $event.target.value || null"
          >
            <option value="">{{ t('PLATFORM_NAV.WEBSITE_FOLDERS') }}</option>
            <option
              v-for="folder in folders"
              :key="folder.key"
              :value="folder.key"
            >
              {{
                t('PLATFORM_NAV.FOLDER_COUNT', {
                  folder: folder.key.slice(website.length),
                  count: folder.count,
                })
              }}
            </option>
          </select>
          <span
            class="i-lucide-chevron-down size-3.5 text-n-slate-10 pointer-events-none absolute end-2.5"
            aria-hidden="true"
          />
        </div>
      </div>
    </div>
    <div v-else-if="hasCards" class="mb-2">
      <div class="mb-3 flex items-center justify-between gap-3">
        <h2 class="m-0 text-sm font-semibold text-n-slate-12">
          {{ t('PLATFORM_NAV.BROWSE_WEBSITES') }}
        </h2>
        <Button
          :label="t('PLATFORM_NAV.ALL_SOURCES')"
          size="xs"
          variant="link"
          @click="browse('*')"
        />
      </div>
      <ul
        class="grid grid-cols-1 gap-3 p-0 m-0 list-none sm:grid-cols-2 xl:grid-cols-3"
      >
        <li
          v-for="site in websites"
          :key="site.host"
          class="relative flex flex-col gap-3 p-4 transition-colors border rounded-xl border-n-weak bg-n-solid-1 hover:border-n-brand/60 focus-within:border-n-brand/60"
        >
          <div class="flex items-center w-full gap-3">
            <span
              class="flex items-center justify-center rounded-lg size-9 shrink-0 bg-n-brand/10 text-n-brand"
              aria-hidden="true"
            >
              <span
                class="size-4"
                :class="
                  site.host === 'files'
                    ? 'i-lucide-file-text'
                    : 'i-lucide-globe'
                "
              />
            </span>
            <!-- The stretched button makes the whole card open the website. -->
            <button
              type="button"
              class="flex flex-col flex-1 min-w-0 text-start after:absolute after:inset-0 after:rounded-xl focus-visible:outline-none"
              @click="browse(site.host)"
            >
              <span class="text-sm font-semibold truncate text-n-slate-12">
                {{ label(site.host) }}
              </span>
              <span class="text-xs text-n-slate-11">
                {{
                  t(
                    site.host === 'files'
                      ? 'PLATFORM_NAV.SOURCE_COUNT'
                      : 'PLATFORM_NAV.PAGES',
                    { count: site.count }
                  )
                }}
              </span>
            </button>
            <Button
              v-if="canManage && site.source"
              v-tooltip.top="t('PLATFORM_NAV.CHOOSE_PAGES_HINT')"
              class="relative z-10"
              size="xs"
              variant="faded"
              icon="i-lucide-list-checks"
              :label="t('PLATFORM_NAV.CHOOSE_PAGES')"
              @click="emit('manage', site.source)"
            />
          </div>
          <div class="flex items-center w-full gap-2">
            <span
              v-if="site.count > 0"
              class="flex flex-1 h-1.5 overflow-hidden rounded-full bg-n-slate-4"
              data-test="health-bar"
              aria-hidden="true"
            >
              <span
                v-for="segment in segments(site)"
                :key="segment.state"
                class="h-full"
                :class="segment.color"
                :style="{ width: segment.width }"
              />
            </span>
            <span
              class="text-xs font-medium shrink-0"
              :class="health(site).tone"
            >
              {{ health(site).text }}
            </span>
          </div>
        </li>
        <li
          v-for="source in pendingSources"
          :key="`source-${source.id}`"
          class="flex flex-col gap-3 p-4 border border-dashed rounded-xl border-n-strong"
        >
          <div class="flex items-center w-full gap-3">
            <span
              class="flex items-center justify-center rounded-lg size-9 shrink-0 bg-n-alpha-2 text-n-slate-11"
              aria-hidden="true"
            >
              <span class="i-lucide-globe size-4" />
            </span>
            <span class="flex flex-col flex-1 min-w-0">
              <span class="text-sm font-semibold truncate text-n-slate-12">
                {{ hostOf(source.url) }}
              </span>
              <span class="text-xs text-n-slate-11">
                {{ pendingText(source) }}
              </span>
            </span>
          </div>
          <Button
            v-if="canManage"
            size="sm"
            icon="i-lucide-list-checks"
            :label="t('PLATFORM_NAV.CHOOSE_PAGES')"
            @click="emit('manage', source)"
          />
        </li>
      </ul>
    </div>
  </div>
</template>

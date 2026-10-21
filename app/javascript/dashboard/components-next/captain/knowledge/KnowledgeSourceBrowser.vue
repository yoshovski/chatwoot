<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import api from 'dashboard/api/captain/knowledgeSources';
import Button from 'next/button/Button.vue';

const props = defineProps({ assistantId: { type: Number, required: true } });
const emit = defineEmits(['loaded']);
const website = defineModel('website', { type: String, default: null });
const section = defineModel('section', { type: String, default: null });
const { t } = useI18n();
const request = useAbortableRequest();
const sections = ref([]);
const error = ref(false);
const websites = computed(() => {
  const grouped = new Map();
  sections.value.forEach(item => {
    const host = item.key.split('/')[0];
    const group = grouped.get(host) || { host, count: 0, failed: 0 };
    group.count += item.count;
    group.failed += item.failed;
    grouped.set(host, group);
  });
  return [...grouped.values()];
});
const folders = computed(() =>
  sections.value.filter(item => item.key.startsWith(`${website.value}/`))
);
const label = host => (host === 'files' ? t('PLATFORM_NAV.FILES') : host);
const load = async () => {
  error.value = false;
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
    <template v-if="websites.length">
      <div v-if="website" class="mb-4 flex flex-wrap items-center gap-3">
        <Button
          :label="t('PLATFORM_NAV.ALL_WEBSITES')"
          variant="link"
          size="sm"
          @click="browse(null)"
        />
        <span
          class="i-lucide-chevron-right size-4 text-n-slate-10"
          aria-hidden="true"
        />
        <span class="text-sm font-medium text-n-slate-12">
          {{ website === '*' ? t('PLATFORM_NAV.ALL_SOURCES') : label(website) }}
        </span>
        <div
          v-if="folders.length"
          class="ms-auto flex items-center gap-2 text-sm text-n-slate-11"
        >
          <span class="text-xs font-medium text-n-slate-10 hidden sm:inline">
            {{ t('PLATFORM_NAV.FILTER_BY_FOLDER') }}:
          </span>
          <div
            class="relative flex items-center rounded-lg border border-n-weak bg-n-solid-1 px-2.5 py-1.5 text-sm text-n-slate-12 hover:bg-n-alpha-1 hover:border-n-slate-6 transition-all shadow-xs"
          >
            <span
              class="i-lucide-folder size-4 text-n-slate-10 shrink-0 me-1.5"
              aria-hidden="true"
            />
            <select
              :value="section || ''"
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
      <div v-else class="mb-4">
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
          class="grid grid-cols-1 gap-3 p-0 m-0 list-none sm:grid-cols-2 lg:grid-cols-3"
        >
          <li v-for="site in websites" :key="site.host">
            <button
              type="button"
              class="flex flex-col w-full h-full gap-3 p-4 text-start transition-colors border rounded-xl border-n-weak bg-n-solid-1 hover:border-n-brand/60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
              @click="browse(site.host)"
            >
              <span class="flex items-center w-full gap-3">
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
                <span class="flex flex-col flex-1 min-w-0">
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
                </span>
                <span
                  class="i-lucide-chevron-right size-4 text-n-slate-10 rtl:rotate-180"
                  aria-hidden="true"
                />
              </span>
              <span class="flex items-center w-full gap-2">
                <span
                  v-if="site.count > 0"
                  class="flex flex-1 h-1.5 overflow-hidden rounded-full bg-n-slate-4"
                  aria-hidden="true"
                >
                  <span
                    v-if="site.failed"
                    class="h-full bg-n-ruby-9"
                    :style="{ width: `${(site.failed / site.count) * 100}%` }"
                  />
                </span>
                <span
                  class="text-xs font-medium shrink-0"
                  :class="site.failed ? 'text-n-ruby-11' : 'text-n-slate-10'"
                >
                  {{
                    site.failed
                      ? t('PLATFORM_NAV.FAILED_PAGES', { count: site.failed })
                      : t('PLATFORM_NAV.NO_FAILURES')
                  }}
                </span>
              </span>
            </button>
          </li>
        </ul>
      </div>
    </template>
  </div>
</template>

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
          class="m-0 list-none grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 p-0"
        >
          <li
            v-for="site in websites"
            :key="site.host"
            class="flex flex-col justify-between rounded-xl border border-n-weak bg-n-solid-1 p-3.5 hover:border-n-brand/60 hover:shadow-xs transition-all cursor-pointer"
            @click="browse(site.host)"
          >
            <div>
              <div class="flex items-center justify-between mb-2">
                <span
                  class="size-8 rounded-lg bg-n-brand/10 text-n-brand flex items-center justify-center shrink-0"
                >
                  <span
                    :class="
                      site.host === 'files'
                        ? 'i-lucide-file-text size-4'
                        : 'i-lucide-globe size-4'
                    "
                  />
                </span>
                <Button
                  :label="t('PLATFORM_NAV.MANAGE_PAGES')"
                  icon="i-lucide-arrow-right"
                  trailing-icon
                  color="slate"
                  variant="faded"
                  size="xs"
                  @click.stop="browse(site.host)"
                />
              </div>
              <span class="break-words text-sm font-semibold text-n-slate-12">
                {{ label(site.host) }}
              </span>
              <p class="m-0 mt-1 text-xs text-n-slate-11">
                {{
                  t(
                    site.host === 'files'
                      ? 'PLATFORM_NAV.SOURCE_COUNT'
                      : 'PLATFORM_NAV.PAGES',
                    { count: site.count }
                  )
                }}
                <span
                  v-if="site.failed"
                  class="ms-1.5 text-n-ruby-11 font-medium"
                >
                  {{ t('PLATFORM_NAV.FAILED_PAGES', { count: site.failed }) }}
                </span>
              </p>
            </div>
            <div
              v-if="site.count > 0"
              class="mt-3 h-1 w-full bg-n-slate-3 rounded-full overflow-hidden flex"
              :aria-label="`${site.count - site.failed} ready, ${site.failed} failed`"
            >
              <div
                class="bg-n-teal-9 h-full"
                :style="{
                  width: `${((site.count - site.failed) / site.count) * 100}%`,
                }"
              />
              <div
                v-if="site.failed"
                class="bg-n-ruby-9 h-full"
                :style="{ width: `${(site.failed / site.count) * 100}%` }"
              />
            </div>
          </li>
        </ul>
      </div>
    </template>
  </div>
</template>

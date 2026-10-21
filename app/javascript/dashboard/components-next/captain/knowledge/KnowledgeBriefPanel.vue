<script setup>
import { computed, ref, watch } from 'vue';
import { useTimeoutPoll } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import api from 'dashboard/api/captain/knowledgeSources';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const props = defineProps({ assistantId: { type: Number, required: true } });

const POLL_INTERVAL = 2500;
const MAX_SOURCES = 60;
const OVERVIEW_LENGTH = 1000;
const TOPIC_LENGTH = 400;

const { t } = useI18n();
const request = useAbortableRequest();
const brief = ref(null);
const draft = ref(null);
const selectedIds = ref([]);
const choosingSources = ref(false);
const error = ref('');
const saving = ref(false);

const generating = computed(
  () =>
    ['queued', 'generating'].includes(brief.value?.status) &&
    !brief.value?.recoverable
);
const active = computed(
  () => brief.value?.enabled && brief.value?.published_usable
);
const hasDraft = computed(() => Boolean(draft.value?.overview));
const draftIsPublished = computed(
  () => brief.value?.draft?.revision === brief.value?.published?.revision
);
const statusKey = computed(() => {
  if (generating.value) return 'GENERATING';
  if (brief.value?.status === 'failed') return 'FAILED';
  if (active.value && brief.value?.sources_changed) return 'SOURCES_CHANGED';
  if (active.value) return 'ENABLED';
  if (brief.value?.enabled) return 'UNAVAILABLE';
  return hasDraft.value ? 'DRAFT' : 'DISABLED';
});
const STATUS_PILL_CLASSES = {
  ENABLED: 'bg-n-teal-3 text-n-teal-11',
  SOURCES_CHANGED: 'bg-n-amber-3 text-n-amber-11',
  UNAVAILABLE: 'bg-n-ruby-3 text-n-ruby-11',
  FAILED: 'bg-n-ruby-3 text-n-ruby-11',
  GENERATING: 'bg-n-blue-3 text-n-blue-11',
  DRAFT: 'bg-n-blue-3 text-n-blue-11',
  DISABLED: 'bg-n-alpha-2 text-n-slate-11',
};
const statusPillClass = computed(() => STATUS_PILL_CLASSES[statusKey.value]);

let poll;
const load = async () => {
  try {
    const response = await request.run(signal =>
      api.brief(props.assistantId, signal)
    );
    if (!response) return;
    const previousGeneration = brief.value?.generated_at;
    brief.value = response.data;
    if (!draft.value || previousGeneration !== response.data.generated_at) {
      draft.value = JSON.parse(JSON.stringify(response.data.draft));
      selectedIds.value = response.data.draft.document_ids || [];
    }
    if (!generating.value) poll.pause();
  } catch {
    error.value = t('CAPTAIN.KNOWLEDGE_BRIEF.ERROR');
  }
};
poll = useTimeoutPoll(load, POLL_INTERVAL, { immediate: false });
watch(
  () => props.assistantId,
  () => {
    brief.value = null;
    draft.value = null;
    poll.pause();
    load();
  },
  { immediate: true }
);

const sourceSearch = ref('');
const sourceReasons = computed(() => brief.value?.draft?.source_reasons || {});
const suggestedIds = computed(() => brief.value?.draft?.document_ids || []);
const matchesSearch = source => {
  const query = sourceSearch.value.trim().toLowerCase();
  if (!query) return true;
  return [source.name, source.url].some(value =>
    value?.toLowerCase().includes(query)
  );
};
// Suggested sources first with the reason they were picked, then the rest by website section.
const sourceGroups = computed(() => {
  const sources = (brief.value?.sources || []).filter(matchesSearch);
  const suggested = new Set(suggestedIds.value);
  const groups = [];
  const picked = sources.filter(source => suggested.has(source.id));
  if (picked.length) groups.push({ key: 'suggested', sources: picked });
  const bySection = new Map();
  sources
    .filter(source => !suggested.has(source.id))
    .forEach(source => {
      if (!bySection.has(source.section)) bySection.set(source.section, []);
      bySection.get(source.section).push(source);
    });
  [...bySection.entries()]
    .sort((a, b) => b[1].length - a[1].length)
    .forEach(([section, items]) =>
      groups.push({ key: section, section, sources: items })
    );
  return groups;
});
const groupLabel = group => {
  if (group.key === 'suggested') {
    return t('CAPTAIN.KNOWLEDGE_BRIEF.SUGGESTED_SOURCES');
  }
  if (group.section === 'files') return t('CAPTAIN.DOCUMENT_SECTIONS.FILES');
  return group.section;
};
const selectSuggested = () => {
  selectedIds.value = suggestedIds.value.slice(0, MAX_SOURCES);
};

const sourceNames = ids =>
  (ids || [])
    .map(
      id =>
        brief.value?.sources.find(source => source.id === id)?.name || `#${id}`
    )
    .join(', ');

const editingOverview = ref(false);
const editingTopic = ref(null);

const toggleSource = (id, include) => {
  const ids = new Set(selectedIds.value);
  if (include) ids.add(id);
  else ids.delete(id);
  selectedIds.value = [...ids];
};

// Without ids the server picks the sources that best explain the business.
const generate = async ids => {
  error.value = '';
  saving.value = true;
  try {
    const { data } = await api.generateBrief(props.assistantId, ids);
    brief.value = data;
    choosingSources.value = false;
    poll.resume();
  } catch (exception) {
    error.value =
      exception.response?.data?.error || t('CAPTAIN.KNOWLEDGE_BRIEF.ERROR');
  } finally {
    saving.value = false;
  }
};
const removeTopic = index => {
  draft.value.topics.splice(index, 1);
  editingTopic.value = null;
};
const publish = async () => {
  error.value = '';
  saving.value = true;
  try {
    const { data } = await api.publishBrief(props.assistantId, draft.value);
    brief.value = data;
  } catch (exception) {
    error.value =
      exception.response?.data?.error ||
      t('CAPTAIN.KNOWLEDGE_BRIEF.PUBLISH_ERROR');
  } finally {
    saving.value = false;
  }
};
const disable = async () => {
  saving.value = true;
  try {
    const { data } = await api.disableBrief(props.assistantId);
    brief.value = data;
  } catch {
    error.value = t('CAPTAIN.KNOWLEDGE_BRIEF.ERROR');
  } finally {
    saving.value = false;
  }
};
</script>

<template>
  <section
    class="flex flex-col gap-4 px-5 py-4 rounded-xl outline outline-1 outline-n-weak bg-n-solid-1"
  >
    <header class="flex flex-wrap items-start justify-between gap-3">
      <div class="flex flex-col min-w-0 gap-1">
        <div class="flex items-center gap-2">
          <h3 class="m-0 text-sm font-semibold text-n-slate-12">
            {{ $t('CAPTAIN.KNOWLEDGE_BRIEF.TITLE') }}
          </h3>
          <span
            v-if="brief"
            v-tooltip.top="$t(`CAPTAIN.KNOWLEDGE_BRIEF.STATUS.${statusKey}`)"
            class="px-2 py-0.5 text-xs font-medium rounded-full"
            :class="statusPillClass"
            role="status"
          >
            {{ $t(`CAPTAIN.KNOWLEDGE_BRIEF.STATUS_PILL.${statusKey}`) }}
          </span>
        </div>
        <p class="m-0 text-sm text-n-slate-11">
          {{ $t('CAPTAIN.KNOWLEDGE_BRIEF.HELP') }}
        </p>
      </div>
      <div class="flex items-center gap-1">
        <Button
          size="sm"
          variant="ghost"
          color="slate"
          :label="$t('CAPTAIN.KNOWLEDGE_BRIEF.CHOOSE_SOURCES')"
          :disabled="generating || !brief?.sources.length"
          @click="choosingSources = !choosingSources"
        />
        <Button
          size="sm"
          :variant="hasDraft ? 'faded' : 'solid'"
          :color="hasDraft ? 'slate' : 'blue'"
          :icon="hasDraft ? 'i-lucide-refresh-cw' : 'i-lucide-sparkles'"
          :label="
            $t(
              hasDraft
                ? 'CAPTAIN.KNOWLEDGE_BRIEF.REGENERATE'
                : 'CAPTAIN.KNOWLEDGE_BRIEF.GENERATE'
            )
          "
          :is-loading="generating"
          :disabled="generating || saving || !brief?.sources.length"
          @click="generate()"
        />
      </div>
    </header>

    <p
      v-if="brief && !brief.sources.length"
      class="m-0 text-sm text-n-slate-11"
    >
      {{ $t('CAPTAIN.KNOWLEDGE_BRIEF.NO_SOURCES') }}
    </p>
    <p
      v-else-if="brief && statusKey !== 'ENABLED' && statusKey !== 'DRAFT'"
      class="m-0 text-xs text-n-slate-11"
    >
      {{ $t(`CAPTAIN.KNOWLEDGE_BRIEF.STATUS.${statusKey}`) }}
    </p>

    <div
      v-if="choosingSources"
      class="flex flex-col gap-2 p-3 rounded-lg bg-n-alpha-1"
    >
      <p class="m-0 text-xs text-n-slate-11">
        {{
          $t('CAPTAIN.KNOWLEDGE_BRIEF.SOURCES_HELP', {
            count: selectedIds.length,
            max: MAX_SOURCES,
          })
        }}
      </p>
      <div class="flex flex-wrap items-center gap-2">
        <Input
          v-model="sourceSearch"
          type="search"
          class="flex-1 min-w-48"
          :placeholder="$t('CAPTAIN.KNOWLEDGE_BRIEF.SEARCH_SOURCES')"
        />
        <Button
          size="sm"
          variant="faded"
          :label="$t('CAPTAIN.KNOWLEDGE_BRIEF.SELECT_SUGGESTED')"
          :disabled="!suggestedIds.length"
          @click="selectSuggested"
        />
        <Button
          size="sm"
          variant="ghost"
          color="slate"
          :label="$t('CAPTAIN.KNOWLEDGE_BRIEF.CLEAR_SOURCES')"
          :disabled="!selectedIds.length"
          @click="selectedIds = []"
        />
      </div>
      <div class="flex flex-col gap-3 overflow-auto max-h-72">
        <div
          v-for="group in sourceGroups"
          :key="group.key"
          class="flex flex-col gap-1"
        >
          <span class="text-xs font-medium text-n-slate-11">
            {{ groupLabel(group) }}
          </span>
          <label
            v-for="source in group.sources"
            :key="source.id"
            class="flex items-center gap-2 text-sm text-n-slate-12"
          >
            <Checkbox
              :model-value="selectedIds.includes(source.id)"
              :disabled="
                !selectedIds.includes(source.id) &&
                selectedIds.length >= MAX_SOURCES
              "
              @update:model-value="include => toggleSource(source.id, include)"
            />
            <span class="flex-1 min-w-0 truncate" :title="source.url">
              {{ source.name || source.url }}
            </span>
            <span
              v-if="sourceReasons[source.id]"
              class="shrink-0 rounded-md bg-n-alpha-2 px-1.5 py-0.5 text-xs text-n-slate-11"
            >
              {{ sourceReasons[source.id] }}
            </span>
          </label>
        </div>
        <p v-if="!sourceGroups.length" class="m-0 text-sm text-n-slate-11">
          {{ $t('CAPTAIN.KNOWLEDGE_BRIEF.NO_MATCHING_SOURCES') }}
        </p>
      </div>
      <div>
        <Button
          size="sm"
          :label="$t('CAPTAIN.KNOWLEDGE_BRIEF.GENERATE_SELECTED')"
          :disabled="generating || saving || !selectedIds.length"
          @click="generate(selectedIds)"
        />
      </div>
    </div>

    <template v-if="hasDraft">
      <div class="flex flex-col gap-1.5">
        <div class="flex items-center justify-between gap-2">
          <h4 class="m-0 text-xs font-medium uppercase text-n-slate-10">
            {{ $t('CAPTAIN.KNOWLEDGE_BRIEF.OVERVIEW') }}
          </h4>
          <div class="flex items-center gap-1">
            <span
              v-if="draft.overview.document_ids?.length"
              v-tooltip.top="sourceNames(draft.overview.document_ids)"
              class="px-1.5 py-0.5 text-xs rounded-md bg-n-alpha-2 text-n-slate-11"
            >
              {{
                $t('CAPTAIN.KNOWLEDGE_BRIEF.SOURCE_COUNT', {
                  count: draft.overview.document_ids.length,
                })
              }}
            </span>
            <Button
              size="xs"
              variant="ghost"
              color="slate"
              :label="
                $t(
                  editingOverview
                    ? 'CAPTAIN.KNOWLEDGE_BRIEF.DONE'
                    : 'CAPTAIN.KNOWLEDGE_BRIEF.EDIT'
                )
              "
              @click="editingOverview = !editingOverview"
            />
          </div>
        </div>
        <template v-if="editingOverview">
          <textarea
            v-model="draft.overview.text"
            :maxlength="OVERVIEW_LENGTH"
            rows="5"
            :aria-label="$t('CAPTAIN.KNOWLEDGE_BRIEF.OVERVIEW')"
            class="w-full p-3 mb-0 text-sm rounded-lg border border-n-weak bg-n-background text-n-slate-12 focus:border-n-brand focus:outline-none"
          />
          <span class="text-xs text-end text-n-slate-10">
            {{
              $t('CAPTAIN.KNOWLEDGE_BRIEF.LENGTH', {
                count: (draft.overview.text || '').length,
                max: OVERVIEW_LENGTH,
              })
            }}
          </span>
        </template>
        <p
          v-else
          class="m-0 text-sm leading-relaxed whitespace-pre-line text-n-slate-12"
        >
          {{ draft.overview.text }}
        </p>
      </div>

      <div class="flex flex-col gap-1">
        <h4 class="m-0 text-xs font-medium uppercase text-n-slate-10">
          {{ $t('CAPTAIN.KNOWLEDGE_BRIEF.TOPICS_TITLE') }}
        </h4>
        <ul class="flex flex-col m-0 divide-y list-none divide-n-weak">
          <li
            v-for="(topic, index) in draft.topics"
            :key="index"
            class="flex flex-col gap-2 py-2.5"
          >
            <template v-if="editingTopic === index">
              <Input
                v-model="topic.title"
                :placeholder="$t('CAPTAIN.KNOWLEDGE_BRIEF.TOPIC_NAME')"
              />
              <textarea
                v-model="topic.summary"
                :maxlength="TOPIC_LENGTH"
                rows="3"
                :aria-label="$t('CAPTAIN.KNOWLEDGE_BRIEF.SUMMARY')"
                class="w-full p-3 mb-0 text-sm rounded-lg border border-n-weak bg-n-background text-n-slate-12 focus:border-n-brand focus:outline-none"
              />
              <div class="flex items-center justify-between gap-2">
                <span class="text-xs text-n-slate-10">
                  {{
                    $t('CAPTAIN.KNOWLEDGE_BRIEF.LENGTH', {
                      count: (topic.summary || '').length,
                      max: TOPIC_LENGTH,
                    })
                  }}
                </span>
                <Button
                  size="xs"
                  variant="faded"
                  color="slate"
                  :label="$t('CAPTAIN.KNOWLEDGE_BRIEF.DONE')"
                  @click="editingTopic = null"
                />
              </div>
            </template>
            <div v-else class="flex items-start gap-3 group">
              <div class="flex flex-col flex-1 min-w-0 gap-0.5">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ topic.title }}
                </span>
                <span class="text-sm text-n-slate-11 line-clamp-2">
                  {{ topic.summary }}
                </span>
              </div>
              <span
                v-if="topic.document_ids?.length"
                v-tooltip.top="sourceNames(topic.document_ids)"
                class="shrink-0 px-1.5 py-0.5 text-xs rounded-md bg-n-alpha-2 text-n-slate-11"
              >
                {{
                  $t('CAPTAIN.KNOWLEDGE_BRIEF.SOURCE_COUNT', {
                    count: topic.document_ids.length,
                  })
                }}
              </span>
              <div
                class="flex items-center opacity-0 shrink-0 group-hover:opacity-100 focus-within:opacity-100"
              >
                <Button
                  size="xs"
                  variant="ghost"
                  color="slate"
                  icon="i-lucide-pencil"
                  :aria-label="$t('CAPTAIN.KNOWLEDGE_BRIEF.EDIT')"
                  @click="editingTopic = index"
                />
                <Button
                  size="xs"
                  variant="ghost"
                  color="slate"
                  icon="i-lucide-trash-2"
                  :aria-label="$t('CAPTAIN.KNOWLEDGE_BRIEF.REMOVE_TOPIC')"
                  @click="removeTopic(index)"
                />
              </div>
            </div>
          </li>
        </ul>
      </div>
    </template>

    <p v-if="error" role="alert" class="m-0 text-sm text-n-ruby-11">
      {{ error }}
    </p>
    <footer
      v-if="hasDraft || brief?.enabled"
      class="flex flex-wrap items-center justify-end gap-2 pt-3 border-t border-n-weak"
    >
      <Button
        v-if="brief?.enabled"
        size="sm"
        variant="ghost"
        color="slate"
        :disabled="saving"
        :label="$t('CAPTAIN.KNOWLEDGE_BRIEF.DISABLE')"
        @click="disable"
      />
      <Button
        v-if="hasDraft"
        size="sm"
        :label="
          $t(
            active && draftIsPublished
              ? 'CAPTAIN.KNOWLEDGE_BRIEF.SAVE'
              : 'CAPTAIN.KNOWLEDGE_BRIEF.PUBLISH'
          )
        "
        :disabled="saving || generating || !brief?.draft_usable"
        :is-loading="saving"
        @click="publish"
      />
    </footer>
  </section>
</template>

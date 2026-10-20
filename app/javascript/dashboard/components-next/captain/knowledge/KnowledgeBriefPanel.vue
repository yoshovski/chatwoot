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
const statusTone = computed(() => {
  if (statusKey.value === 'FAILED' || statusKey.value === 'UNAVAILABLE') {
    return 'text-n-ruby-11';
  }
  if (statusKey.value === 'SOURCES_CHANGED') return 'text-n-amber-11';
  return 'text-n-slate-11';
});

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

const sourceName = id =>
  brief.value?.sources.find(source => source.id === id)?.name || `#${id}`;
const sourceNames = ids => (ids || []).map(sourceName).join(', ');
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
const removeTopic = index => draft.value.topics.splice(index, 1);
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
    class="flex flex-col gap-4 rounded-xl px-5 py-4 outline outline-1 outline-n-weak bg-n-solid-1"
  >
    <div class="flex flex-wrap items-start justify-between gap-3">
      <div class="flex min-w-0 flex-col gap-0.5">
        <h3 class="m-0 text-sm font-medium text-n-slate-12">
          {{ $t('CAPTAIN.KNOWLEDGE_BRIEF.TITLE') }}
        </h3>
        <p class="m-0 text-sm text-n-slate-11">
          {{ $t('CAPTAIN.KNOWLEDGE_BRIEF.HELP') }}
        </p>
        <p class="m-0 text-xs" :class="statusTone" role="status">
          {{ $t(`CAPTAIN.KNOWLEDGE_BRIEF.STATUS.${statusKey}`) }}
        </p>
      </div>
      <div class="flex flex-wrap items-center gap-2">
        <Button
          size="sm"
          :variant="hasDraft ? 'faded' : 'solid'"
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
        <Button
          size="sm"
          variant="ghost"
          color="slate"
          :label="$t('CAPTAIN.KNOWLEDGE_BRIEF.CHOOSE_SOURCES')"
          :disabled="generating || !brief?.sources.length"
          @click="choosingSources = !choosingSources"
        />
      </div>
    </div>

    <p
      v-if="brief && !brief.sources.length"
      class="m-0 text-sm text-n-slate-11"
    >
      {{ $t('CAPTAIN.KNOWLEDGE_BRIEF.NO_SOURCES') }}
    </p>

    <div
      v-if="choosingSources"
      class="flex flex-col gap-2 rounded-lg border border-n-weak p-3"
    >
      <p class="m-0 text-xs text-n-slate-11">
        {{
          $t('CAPTAIN.KNOWLEDGE_BRIEF.SOURCES_HELP', {
            count: selectedIds.length,
            max: MAX_SOURCES,
          })
        }}
      </p>
      <p class="m-0 text-xs text-n-slate-11">
        {{ $t('CAPTAIN.KNOWLEDGE_BRIEF.SUGGESTION_HELP') }}
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
      <div class="flex max-h-80 flex-col gap-3 overflow-auto">
        <div
          v-for="group in sourceGroups"
          :key="group.key"
          class="flex flex-col gap-1.5"
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
            <span class="min-w-0 flex-1 truncate" :title="source.url">
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
      <label class="flex flex-col gap-2 text-sm font-medium text-n-slate-12">
        {{ $t('CAPTAIN.KNOWLEDGE_BRIEF.OVERVIEW') }}
        <textarea
          v-model="draft.overview.text"
          :maxlength="OVERVIEW_LENGTH"
          rows="4"
          class="w-full rounded-lg border border-n-weak bg-n-background p-3 text-sm font-normal"
        />
      </label>
      <p class="m-0 text-xs text-n-slate-11">
        {{
          $t('CAPTAIN.KNOWLEDGE_BRIEF.BASED_ON', {
            sources: sourceNames(draft.overview.document_ids),
          })
        }}
      </p>
      <div
        v-for="(topic, index) in draft.topics"
        :key="index"
        class="flex flex-col gap-2 rounded-lg border border-n-weak p-3"
      >
        <div class="flex items-end gap-2">
          <Input
            v-model="topic.title"
            class="flex-1"
            :label="$t('CAPTAIN.KNOWLEDGE_BRIEF.TOPIC')"
          />
          <Button
            size="sm"
            variant="ghost"
            color="slate"
            icon="i-lucide-trash-2"
            :aria-label="$t('CAPTAIN.KNOWLEDGE_BRIEF.REMOVE_TOPIC')"
            @click="removeTopic(index)"
          />
        </div>
        <textarea
          v-model="topic.summary"
          :maxlength="TOPIC_LENGTH"
          rows="3"
          :aria-label="$t('CAPTAIN.KNOWLEDGE_BRIEF.SUMMARY')"
          class="w-full rounded-lg border border-n-weak bg-n-background p-3 text-sm"
        />
        <p class="m-0 text-xs text-n-slate-11">
          {{
            $t('CAPTAIN.KNOWLEDGE_BRIEF.BASED_ON', {
              sources: sourceNames(topic.document_ids),
            })
          }}
        </p>
      </div>
    </template>

    <p v-if="error" role="alert" class="m-0 text-sm text-n-ruby-11">
      {{ error }}
    </p>
    <div
      v-if="hasDraft || brief?.enabled"
      class="flex flex-wrap items-center justify-between gap-3"
    >
      <Button
        v-if="brief?.enabled"
        size="sm"
        variant="faded"
        color="slate"
        :disabled="saving"
        :label="$t('CAPTAIN.KNOWLEDGE_BRIEF.DISABLE')"
        @click="disable"
      />
      <Button
        v-if="hasDraft"
        size="sm"
        class="ms-auto"
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
    </div>
  </section>
</template>

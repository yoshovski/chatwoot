<script setup>
import { computed, nextTick, ref, watch } from 'vue';
import { useTimeoutPoll } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import api from 'dashboard/api/captain/knowledgeSources';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const props = defineProps({ assistantId: { type: Number, required: true } });
const { t } = useI18n();
const request = useAbortableRequest();
const brief = ref(null);
const draft = ref(null);
const selectedIds = ref([]);
const dialog = ref(null);
const error = ref('');
const saving = ref(false);
const generating = computed(
  () =>
    ['queued', 'generating'].includes(brief.value?.status) &&
    !brief.value?.recoverable
);
const active = computed(
  () => brief.value?.enabled && brief.value?.published_current
);
let poll;
const statusKey = computed(() => {
  if (generating.value) return 'GENERATING';
  if (brief.value?.enabled && !brief.value?.published_current) return 'STALE';
  return active.value ? 'ENABLED' : 'DISABLED';
});
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
    }
    if (!generating.value) poll.pause();
  } catch {
    error.value = t('CAPTAIN.KNOWLEDGE_BRIEF.ERROR');
  }
};
poll = useTimeoutPoll(load, 2500, { immediate: false });
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

const open = async () => {
  await load();
  selectedIds.value =
    brief.value?.draft.document_ids ||
    brief.value?.published.document_ids ||
    (brief.value?.sources || []).slice(0, 60).map(source => source.id);
  await nextTick();
  dialog.value.open();
  if (generating.value) poll.resume();
};
const toggleSource = (id, include) => {
  const ids = new Set(selectedIds.value);
  if (include) ids.add(id);
  else ids.delete(id);
  selectedIds.value = [...ids];
};
const generate = async () => {
  error.value = '';
  saving.value = true;
  try {
    const { data } = await api.generateBrief(
      props.assistantId,
      selectedIds.value
    );
    brief.value = data;
    poll.resume();
  } catch (exception) {
    error.value =
      exception.response?.data?.error || t('CAPTAIN.KNOWLEDGE_BRIEF.ERROR');
  } finally {
    saving.value = false;
  }
};
const publish = async () => {
  error.value = '';
  saving.value = true;
  try {
    const { data } = await api.publishBrief(props.assistantId, draft.value);
    brief.value = data;
    dialog.value.close();
  } catch (exception) {
    error.value =
      exception.response?.data?.error || t('CAPTAIN.KNOWLEDGE_BRIEF.STALE');
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
const sourceNames = ids =>
  (ids || [])
    .map(
      id =>
        brief.value?.sources.find(source => source.id === id)?.name || `#${id}`
    )
    .join(', ');
</script>

<template>
  <section
    class="mb-4 flex items-center justify-between gap-4 rounded-xl border border-n-weak p-4"
  >
    <div>
      <h3 class="m-0 text-sm font-medium text-n-slate-12">
        {{ $t('CAPTAIN.KNOWLEDGE_BRIEF.TITLE') }}
      </h3>
      <p class="m-0 mt-1 text-xs text-n-slate-11">
        {{ $t(`CAPTAIN.KNOWLEDGE_BRIEF.${statusKey}`) }}
      </p>
      <p v-if="error" role="alert" class="m-0 mt-1 text-xs text-n-ruby-11">
        {{ error }}
      </p>
    </div>
    <Button
      variant="faded"
      size="sm"
      :label="$t('CAPTAIN.KNOWLEDGE_BRIEF.REVIEW')"
      @click="open"
    />
  </section>
  <Dialog
    ref="dialog"
    width="3xl"
    :title="$t('CAPTAIN.KNOWLEDGE_BRIEF.TITLE')"
    :description="$t('CAPTAIN.KNOWLEDGE_BRIEF.HELP')"
    :show-cancel-button="false"
    :show-confirm-button="false"
  >
    <div class="flex max-h-[70vh] flex-col gap-4 overflow-auto">
      <details class="rounded-lg border border-n-weak p-3" open>
        <summary class="cursor-pointer text-sm font-medium text-n-slate-12">
          {{
            $t('CAPTAIN.KNOWLEDGE_BRIEF.SOURCES', { count: selectedIds.length })
          }}
        </summary>
        <p class="mt-2 text-xs text-n-slate-11">
          {{ $t('CAPTAIN.KNOWLEDGE_BRIEF.SOURCES_HELP') }}
        </p>
        <div class="flex max-h-40 flex-col gap-2 overflow-auto">
          <label
            v-for="source in brief?.sources || []"
            :key="source.id"
            class="flex items-center gap-2 text-sm text-n-slate-12"
          >
            <Checkbox
              :model-value="selectedIds.includes(source.id)"
              :disabled="
                generating ||
                (!selectedIds.includes(source.id) && selectedIds.length >= 60)
              "
              @update:model-value="include => toggleSource(source.id, include)"
            />
            <span class="truncate">{{ source.name || source.url }}</span>
          </label>
        </div>
        <p v-if="!brief?.sources.length" class="text-sm text-n-slate-11">
          {{ $t('CAPTAIN.KNOWLEDGE_BRIEF.NO_SOURCES') }}
        </p>
      </details>
      <div>
        <Button
          variant="faded"
          :label="
            $t(
              generating
                ? 'CAPTAIN.KNOWLEDGE_BRIEF.GENERATING'
                : 'CAPTAIN.KNOWLEDGE_BRIEF.GENERATE'
            )
          "
          :is-loading="generating || saving"
          :disabled="
            generating ||
            saving ||
            !selectedIds.length ||
            selectedIds.length > 60
          "
          @click="generate"
        />
      </div>
      <p v-if="brief?.status === 'failed'" class="m-0 text-sm text-n-ruby-11">
        {{ $t('CAPTAIN.KNOWLEDGE_BRIEF.ERROR') }}
      </p>
      <p
        v-if="brief?.draft.overview && !brief.draft_current"
        class="m-0 text-sm text-n-amber-11"
      >
        {{ $t('CAPTAIN.KNOWLEDGE_BRIEF.STALE') }}
      </p>
      <template v-if="draft?.overview">
        <label class="flex flex-col gap-2 text-sm font-medium text-n-slate-12">
          {{ $t('CAPTAIN.KNOWLEDGE_BRIEF.OVERVIEW') }}
          <textarea
            v-model="draft.overview.text"
            maxlength="1500"
            rows="4"
            class="w-full rounded-lg border border-n-weak bg-n-background p-3 text-sm font-normal"
          />
        </label>
        <p class="m-0 text-xs text-n-slate-11">
          {{ sourceNames(draft.overview.document_ids) }}
        </p>
        <div
          v-for="(topic, index) in draft.topics"
          :key="index"
          class="flex flex-col gap-2 rounded-lg border border-n-weak p-3"
        >
          <Input
            v-model="topic.title"
            :label="$t('CAPTAIN.KNOWLEDGE_BRIEF.TOPIC')"
          />
          <label class="flex flex-col gap-2 text-sm text-n-slate-12">
            {{ $t('CAPTAIN.KNOWLEDGE_BRIEF.SUMMARY') }}
            <textarea
              v-model="topic.summary"
              maxlength="800"
              rows="3"
              class="w-full rounded-lg border border-n-weak bg-n-background p-3 text-sm"
            />
          </label>
          <p class="m-0 text-xs text-n-slate-11">
            {{ sourceNames(topic.document_ids) }}
          </p>
        </div>
      </template>
      <p v-if="error" role="alert" class="m-0 text-sm text-n-ruby-11">
        {{ error }}
      </p>
      <div class="flex items-center justify-between gap-3">
        <Button
          v-if="brief?.enabled"
          variant="faded"
          color="slate"
          :disabled="saving"
          :label="$t('CAPTAIN.KNOWLEDGE_BRIEF.DISABLE')"
          @click="disable"
        />
        <Button
          :label="$t('CAPTAIN.KNOWLEDGE_BRIEF.PUBLISH')"
          :disabled="saving || generating || !brief?.draft_current"
          :is-loading="saving"
          @click="publish"
        />
      </div>
    </div>
    <template #footer />
  </Dialog>
</template>

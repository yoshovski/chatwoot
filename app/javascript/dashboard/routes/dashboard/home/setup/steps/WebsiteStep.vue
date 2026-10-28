<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import StepIntro from './StepIntro.vue';

const props = defineProps({
  guided: { type: Object, required: true },
});

const { t } = useI18n();
const url = ref('');
const urlError = ref('');
const isStarting = ref(false);
const wantsOtherUrl = ref(false);

const phase = computed(() => props.guided.progress.phase);
const progress = computed(() => props.guided.progress);
const source = computed(() => props.guided.source);
const host = computed(() => {
  try {
    return new URL(source.value.url).host.replace(/^www\./, '');
  } catch {
    return source.value?.url || '';
  }
});
const showForm = computed(
  () => phase.value === 'idle' || (wantsOtherUrl.value && !isStarting.value)
);
const readPercent = computed(() =>
  progress.value.total
    ? Math.round((progress.value.ready / progress.value.total) * 100)
    : 0
);
const importError = computed(() => {
  const error = props.guided.importError;
  if (!error) return '';
  return error === 'IMPORT_FAILED'
    ? t('HOME.GUIDED.WEBSITE.IMPORT_FAILED')
    : error;
});

// Finding → picking → reading; `select` is the short moment the recommended pages are being chosen.
const STAGE_ORDER = ['finding', 'select', 'reading', 'done'];
const stages = computed(() => {
  const reached = STAGE_ORDER.indexOf(phase.value);
  return [
    'HOME.GUIDED.WEBSITE.STAGES.FIND',
    'HOME.GUIDED.WEBSITE.STAGES.PICK',
    'HOME.GUIDED.WEBSITE.STAGES.READ',
  ].map((key, index) => ({
    key,
    done: reached > index,
    active: reached === index,
  }));
});

const submit = async () => {
  urlError.value = '';
  const value = url.value.trim();
  if (!value || !/^(https?:\/\/)?[^\s/]+\.[^\s]{2,}/i.test(value)) {
    urlError.value = t('HOME.GUIDED.WEBSITE.INVALID');
    return;
  }
  isStarting.value = true;
  const result = await props.guided.startWebsite(value);
  isStarting.value = false;
  if (result.ok) {
    wantsOtherUrl.value = false;
  } else {
    urlError.value = result.error || t('HOME.GUIDED.WEBSITE.INVALID');
  }
};
</script>

<template>
  <div class="flex flex-col gap-6">
    <StepIntro
      :title="$t('HOME.GUIDED.WEBSITE.TITLE')"
      :description="$t('HOME.GUIDED.WEBSITE.DESCRIPTION')"
    />

    <form
      v-if="showForm"
      class="flex flex-col gap-3 sm:flex-row sm:items-start"
      novalidate
      @submit.prevent="submit"
    >
      <Input
        v-model="url"
        class="flex-1"
        autofocus
        :label="$t('HOME.GUIDED.WEBSITE.LABEL')"
        :placeholder="$t('HOME.GUIDED.WEBSITE.PLACEHOLDER')"
        :message="urlError"
        :message-type="urlError ? 'error' : 'info'"
        :disabled="isStarting"
      />
      <Button
        type="submit"
        class="sm:mt-6"
        :label="$t('HOME.GUIDED.WEBSITE.SUBMIT')"
        :is-loading="isStarting"
      />
    </form>

    <div
      v-else-if="['failed', 'empty'].includes(phase)"
      role="alert"
      class="flex flex-col gap-3 rounded-lg bg-n-alpha-1 p-4"
    >
      <div class="flex items-start gap-2.5">
        <Icon
          icon="i-lucide-circle-alert"
          class="mt-0.5 size-4 shrink-0"
          :class="phase === 'failed' ? 'text-n-ruby-10' : 'text-n-amber-10'"
        />
        <div class="flex flex-col gap-0.5">
          <span class="text-sm font-medium text-n-slate-12">
            {{
              phase === 'failed'
                ? $t('HOME.GUIDED.WEBSITE.FAILED_TITLE')
                : $t('HOME.GUIDED.WEBSITE.EMPTY_TITLE')
            }}
          </span>
          <span class="text-sm text-n-slate-11">
            {{
              phase === 'failed'
                ? $t('HOME.GUIDED.WEBSITE.FAILED_BODY')
                : $t('HOME.GUIDED.WEBSITE.EMPTY_BODY')
            }}
          </span>
        </div>
      </div>
      <div class="flex flex-wrap gap-2 ps-6">
        <Button
          v-if="phase === 'failed'"
          :label="$t('HOME.GUIDED.RETRY')"
          size="sm"
          variant="faded"
          @click="guided.retryImport"
        />
        <router-link
          v-else
          :to="{
            name: 'captain_assistants_index',
            params: { navigationPath: 'captain_assistants_documents_index' },
          }"
        >
          <Button
            :label="$t('HOME.GUIDED.WEBSITE.REVIEW')"
            size="sm"
            variant="faded"
          />
        </router-link>
        <Button
          :label="$t('HOME.GUIDED.WEBSITE.OTHER_URL')"
          size="sm"
          variant="ghost"
          color="slate"
          @click="wantsOtherUrl = true"
        />
      </div>
    </div>

    <div v-else class="flex flex-col gap-4" aria-live="polite">
      <div class="flex items-center gap-2 text-sm text-n-slate-12">
        <Icon icon="i-lucide-globe" class="size-4 text-n-slate-10" />
        <span class="truncate font-medium">{{ host }}</span>
      </div>
      <ol class="flex flex-col gap-3">
        <li
          v-for="stage in stages"
          :key="stage.key"
          class="flex items-center gap-2.5 text-sm"
          :class="
            stage.done || stage.active ? 'text-n-slate-12' : 'text-n-slate-10'
          "
        >
          <Icon
            v-if="stage.done"
            icon="i-lucide-circle-check"
            class="size-4 shrink-0 text-n-teal-10"
          />
          <Spinner
            v-else-if="stage.active"
            :size="16"
            class="shrink-0 text-n-brand"
          />
          <Icon
            v-else
            icon="i-lucide-circle-dashed"
            class="size-4 shrink-0 text-n-slate-9"
          />
          {{ $t(stage.key) }}
        </li>
      </ol>

      <div
        v-if="['reading', 'done'].includes(phase)"
        class="flex flex-col gap-2"
      >
        <div class="h-1.5 w-full overflow-hidden rounded-full bg-n-alpha-2">
          <div
            class="h-full rounded-full bg-n-brand transition-all duration-500"
            :style="{ width: `${readPercent}%` }"
          />
        </div>
        <p class="mb-0 text-sm text-n-slate-11">
          {{
            phase === 'done'
              ? $t(
                  'HOME.GUIDED.WEBSITE.DONE',
                  { ready: progress.ready },
                  progress.ready
                )
              : $t('HOME.GUIDED.WEBSITE.READING', {
                  ready: progress.ready,
                  total: progress.total,
                })
          }}
          <template v-if="progress.failed">
            {{
              $t(
                'HOME.GUIDED.WEBSITE.SOME_FAILED',
                { count: progress.failed },
                progress.failed
              )
            }}
          </template>
        </p>
      </div>
      <p v-else class="mb-0 text-sm text-n-slate-11">
        {{
          $t(
            'HOME.GUIDED.WEBSITE.FINDING',
            { count: progress.found || 0 },
            progress.found || 0
          )
        }}
      </p>
      <p v-if="importError" role="alert" class="mb-0 text-sm text-n-ruby-11">
        {{ importError }}
      </p>
    </div>
  </div>
</template>

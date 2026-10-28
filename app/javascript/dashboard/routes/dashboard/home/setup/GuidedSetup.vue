<script setup>
import { computed, onBeforeUnmount, onMounted, reactive } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useUISettings } from 'dashboard/composables/useUISettings';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import {
  buildSetupProgress,
  FINISHED_SETTING,
  firstOpenGuidedStep,
  GUIDED_STEPS,
  SKIPPED_SETTING,
} from '../homeSetup';
import { useGuidedSetup } from './useGuidedSetup';
import WebsiteStep from './steps/WebsiteStep.vue';
import TestStep from './steps/TestStep.vue';
import GoLiveStep from './steps/GoLiveStep.vue';
import InstallStep from './steps/InstallStep.vue';

const STEP_COMPONENTS = {
  knowledge: WebsiteStep,
  test_agent: TestStep,
  agent_inbox: GoLiveStep,
  chat_widget: InstallStep,
};

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { uiSettings, updateUISettings } = useUISettings();
const guided = reactive(useGuidedSetup());

const skipped = computed(() => uiSettings.value[SKIPPED_SETTING] || []);
const finished = computed(() => uiSettings.value[FINISHED_SETTING] || []);
const checklist = computed(() =>
  buildSetupProgress(guided.setup, skipped.value, finished.value)
);
const stepState = key => checklist.value.steps.find(step => step.key === key);

const currentStep = computed(() =>
  GUIDED_STEPS.includes(route.params.step)
    ? route.params.step
    : firstOpenGuidedStep(checklist.value)
);
const currentIndex = computed(() => GUIDED_STEPS.indexOf(currentStep.value));
const isLastStep = computed(
  () => currentIndex.value === GUIDED_STEPS.length - 1
);
const segments = computed(() =>
  GUIDED_STEPS.map((key, index) => ({
    key,
    label: t(`HOME.GUIDED.STEP_NAMES.${key.toUpperCase()}`),
    current: index === currentIndex.value,
    done: stepState(key)?.done,
    skipped: stepState(key)?.skipped,
  }))
);

const canContinue = computed(() => {
  switch (currentStep.value) {
    case 'knowledge':
      return (
        stepState('knowledge')?.done ||
        ['reading', 'done'].includes(guided.progress.phase)
      );
    case 'test_agent':
      return Boolean(guided.assistantId);
    case 'agent_inbox':
      return Boolean(guided.state?.agent_live);
    default:
      return true;
  }
});

const openStep = step =>
  router.replace({ name: 'account_home_setup', params: { step } });
const closeSetup = () => router.push({ name: 'account_home' });
// Moves on from `key`, not from the current step: skipping changes which step an open URL resolves to.
const goNextFrom = key => {
  const next = GUIDED_STEPS[GUIDED_STEPS.indexOf(key) + 1];
  return next ? openStep(next) : closeSetup();
};
const goBack = () => openStep(GUIDED_STEPS[currentIndex.value - 1]);

const continueStep = () => {
  const key = currentStep.value;
  // Testing leaves no trace the server can count, so finishing it is remembered here.
  if (key === 'test_agent' && !finished.value.includes(key)) {
    updateUISettings({ [FINISHED_SETTING]: [...finished.value, key] });
  }
  goNextFrom(key);
};

const skipStep = () => {
  const key = currentStep.value;
  if (!stepState(key)?.done && !skipped.value.includes(key)) {
    updateUISettings({ [SKIPPED_SETTING]: [...skipped.value, key] });
  }
  goNextFrom(key);
};

const segmentClass = segment => {
  if (segment.done) return 'bg-n-brand';
  if (segment.current) return 'bg-n-brand/50';
  return 'bg-n-alpha-2';
};

onMounted(guided.load);
onBeforeUnmount(guided.stopPolling);
</script>

<template>
  <section class="flex h-full w-full flex-col overflow-y-auto bg-n-background">
    <div
      class="mx-auto flex w-full max-w-[48rem] flex-col gap-5 px-4 pb-24 pt-5 sm:px-6 sm:py-8"
    >
      <header class="flex items-start justify-between gap-3">
        <div class="flex min-w-0 flex-col gap-0.5">
          <p class="mb-0 text-xs font-medium text-n-slate-10">
            {{
              $t('HOME.GUIDED.STEP_OF', {
                current: currentIndex + 1,
                total: GUIDED_STEPS.length,
              })
            }}
          </p>
          <h1 class="mb-0 text-lg font-medium text-n-slate-12">
            {{ $t('HOME.GUIDED.TITLE') }}
          </h1>
        </div>
        <Button
          icon="i-lucide-x"
          variant="ghost"
          color="slate"
          size="sm"
          :aria-label="$t('HOME.GUIDED.CLOSE')"
          @click="closeSetup"
        />
      </header>

      <ol class="grid grid-cols-4 gap-1.5" :aria-label="$t('HOME.GUIDED.TITLE')">
        <li
          v-for="segment in segments"
          :key="segment.key"
          class="flex min-w-0 flex-col gap-1.5"
          :aria-current="segment.current ? 'step' : undefined"
        >
          <span
            class="h-1 w-full rounded-full transition-colors duration-300"
            :class="segmentClass(segment)"
          />
          <button
            type="button"
            class="flex min-w-0 items-center gap-1 text-start text-xs"
            :class="segment.current ? 'text-n-slate-12' : 'text-n-slate-10'"
            @click="openStep(segment.key)"
          >
            <Icon
              v-if="segment.done"
              icon="i-lucide-check"
              class="hidden size-3 shrink-0 text-n-teal-10 sm:inline-block"
            />
            <span class="truncate">{{ segment.label }}</span>
          </button>
        </li>
      </ol>

      <div
        class="flex flex-col rounded-xl bg-n-solid-1 p-4 outline outline-1 -outline-offset-1 outline-n-container sm:p-6"
      >
        <div
          v-if="guided.isLoading"
          class="flex items-center justify-center py-16"
          aria-busy="true"
        >
          <Spinner :size="20" class="text-n-slate-10" />
        </div>
        <div
          v-else-if="guided.loadError"
          role="alert"
          class="flex flex-col items-center justify-center gap-3 py-16 text-center"
        >
          <Icon icon="i-lucide-circle-alert" class="size-5 text-n-ruby-10" />
          <p class="mb-0 text-sm text-n-slate-11">
            {{ $t('HOME.GUIDED.ERROR') }}
          </p>
          <Button
            :label="$t('HOME.GUIDED.RETRY')"
            size="sm"
            variant="faded"
            color="slate"
            @click="guided.load"
          />
        </div>
        <component
          :is="STEP_COMPONENTS[currentStep]"
          v-else
          :guided="guided"
          @open="openStep"
        />
      </div>

      <footer class="flex items-center justify-between gap-2">
        <Button
          v-if="currentIndex > 0"
          :label="$t('HOME.GUIDED.BACK')"
          icon="i-lucide-arrow-left"
          variant="ghost"
          color="slate"
          size="sm"
          @click="goBack"
        />
        <span v-else />
        <div class="flex items-center gap-2">
          <Button
            v-if="!stepState(currentStep)?.done"
            :label="$t('HOME.GUIDED.SKIP')"
            variant="ghost"
            color="slate"
            size="sm"
            @click="skipStep"
          />
          <Button
            :label="
              isLastStep ? $t('HOME.GUIDED.FINISH') : $t('HOME.GUIDED.CONTINUE')
            "
            size="sm"
            :disabled="!canContinue || guided.isLoading"
            @click="continueStep"
          />
        </div>
      </footer>
    </div>
  </section>
</template>

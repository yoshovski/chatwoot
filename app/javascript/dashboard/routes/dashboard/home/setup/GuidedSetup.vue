<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useConfig } from 'dashboard/composables/useConfig';
import { useUISettings } from 'dashboard/composables/useUISettings';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import AuthLogo from 'v3/components/AuthLayout/AuthLogo.vue';
import {
  buildSetupProgress,
  FINISHED_SETTING,
  firstOpenGuidedStep,
  GUIDED_STEPS,
  SKIPPED_SETTING,
} from '../homeSetup';
import { closeAccountOnboarding, OPEN_STEPS } from './accountOnboarding';
import { nextStep, primaryAction } from './stepRules';
import { useGuidedSetup } from './useGuidedSetup';
import { useSetupChat } from './useSetupChat';
import LearnedBanner from './LearnedBanner.vue';
import SetupChat from './SetupChat.vue';
import WebsiteStep from './steps/WebsiteStep.vue';
import TestStep from './steps/TestStep.vue';
import GoLiveStep from './steps/GoLiveStep.vue';
import InstallStep from './steps/InstallStep.vue';

// The setup a new account lands in: full-screen steps with the step on the left and, from "Meet your agent" on, the
// chat widget on the right to talk to the new AI agent. No step waits for the import; Continue and Skip always work.
const STEP_NAMES = {
  knowledge: 'HOME.GUIDED.STEP_NAMES.KNOWLEDGE',
  test_agent: 'HOME.GUIDED.STEP_NAMES.TEST_AGENT',
  agent_inbox: 'HOME.GUIDED.STEP_NAMES.AGENT_INBOX',
  chat_widget: 'HOME.GUIDED.STEP_NAMES.CHAT_WIDGET',
};

const STEP_COMPONENTS = {
  knowledge: WebsiteStep,
  test_agent: TestStep,
  agent_inbox: GoLiveStep,
  chat_widget: InstallStep,
};

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const currentUser = useMapGetter('getCurrentUser');
const { currentAccount } = useAccount();
const { enabledLanguages } = useConfig();
const { uiSettings, updateUISettings } = useUISettings();
const guided = reactive(useGuidedSetup());
const chat = reactive(useSetupChat(computed(() => guided.assistantId)));

const stepView = ref(null);
const isBusy = ref(false);
const actionError = ref('');

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
const segments = computed(() =>
  GUIDED_STEPS.map((key, index) => ({
    key,
    number: index + 1,
    label: t(STEP_NAMES[key]),
    current: index === currentIndex.value,
    done: stepState(key)?.done,
  }))
);

const website = computed(
  () =>
    guided.state?.website_source?.url ||
    currentAccount.value?.custom_attributes?.website ||
    ''
);
const websiteHost = computed(() =>
  website.value.replace(/^https?:\/\//, '').replace(/^www\./, '')
);
const showChat = computed(
  () => currentStep.value !== 'knowledge' && Boolean(guided.assistantId)
);

const primary = computed(() =>
  primaryAction(currentStep.value, {
    websiteStarted: Boolean(guided.state?.website_source),
    liveReady: ['ready', 'importing'].includes(guided.state?.readiness),
    isLive: Boolean(guided.state?.agent_live),
  })
);

const primaryLabel = computed(
  () =>
    ({
      turn_on: t('HOME.GUIDED.LIVE.TURN_ON'),
      finish: t('HOME.GUIDED.FINISH'),
    })[primary.value] || t('HOME.GUIDED.CONTINUE')
);

const openStep = step =>
  router.replace({ name: 'account_home_setup', params: { step } });
const closeSetup = () => router.push({ name: 'account_home' });
// Moves on from `key`, not from the current step: skipping changes which step an open URL resolves to.
const goNextFrom = key => {
  const next = nextStep(key);
  return next ? openStep(next) : closeSetup();
};
const goBack = () => openStep(GUIDED_STEPS[currentIndex.value - 1]);

// Runs the step's own action first (start the import from the address in the form, turn the agent on); a failure
// stays on the step with its message, and Skip still moves on.
const runStepAction = async (key, action) => {
  if (key === 'knowledge') return stepView.value?.submit?.() ?? true;
  if (action !== 'turn_on') return true;
  const result = await guided.goLive();
  if (!result.ok) actionError.value = result.error;
  return result.ok;
};

const continueStep = async () => {
  const key = currentStep.value;
  actionError.value = '';
  isBusy.value = true;
  const ok = await runStepAction(key, primary.value);
  isBusy.value = false;
  if (!ok) return;
  // Testing leaves no trace the server can count, so finishing it is remembered here.
  if (key === 'test_agent' && !finished.value.includes(key)) {
    updateUISettings({ [FINISHED_SETTING]: [...finished.value, key] });
  }
  goNextFrom(key);
};

const skipStep = () => {
  const key = currentStep.value;
  actionError.value = '';
  if (!stepState(key)?.done && !skipped.value.includes(key)) {
    updateUISettings({ [SKIPPED_SETTING]: [...skipped.value, key] });
  }
  goNextFrom(key);
};

const stepProps = computed(() =>
  currentStep.value === 'knowledge' ? { defaultUrl: website.value } : {}
);

const segmentBadgeClass = segment => {
  if (segment.done) return 'bg-n-teal-9 text-white';
  if (segment.current) return 'bg-n-brand text-white';
  return 'bg-n-alpha-2 text-n-slate-11';
};

const closeOpenOnboarding = async () => {
  const account = currentUser.value?.accounts?.find(
    item => item.id === Number(route.params.accountId)
  );
  if (!OPEN_STEPS.includes(account?.onboarding_step)) return;
  try {
    await closeAccountOnboarding({
      step: account.onboarding_step,
      languages: enabledLanguages,
    });
    await store.dispatch('setUser');
  } catch {
    // The router keeps the account in the setup; the next visit tries again.
  }
};

onMounted(() => {
  guided.load();
  closeOpenOnboarding();
});
onBeforeUnmount(guided.stopPolling);
</script>

<template>
  <div class="fixed inset-0 z-50 flex flex-col overflow-y-auto bg-n-background">
    <header
      class="flex items-center gap-4 border-b border-n-weak bg-n-solid-1 px-4 py-3 sm:px-6"
    >
      <AuthLogo class="shrink-0" />
      <ol
        class="mx-auto mb-0 hidden list-none items-center gap-2 p-0 md:flex"
        :aria-label="$t('HOME.GUIDED.TITLE')"
      >
        <li
          v-for="(segment, index) in segments"
          :key="segment.key"
          class="flex items-center gap-2"
          :aria-current="segment.current ? 'step' : undefined"
        >
          <button
            type="button"
            class="flex items-center gap-2 rounded-full px-3 py-1.5 text-sm"
            :class="
              segment.current
                ? 'bg-n-blue-3 font-medium text-n-blue-11'
                : 'text-n-slate-11 hover:text-n-slate-12'
            "
            @click="openStep(segment.key)"
          >
            <span
              class="flex size-5 items-center justify-center rounded-full text-xs"
              :class="segmentBadgeClass(segment)"
            >
              <Icon v-if="segment.done" icon="i-lucide-check" class="size-3" />
              <template v-else>{{ segment.number }}</template>
            </span>
            {{ segment.label }}
          </button>
          <span v-if="index < segments.length - 1" class="h-px w-6 bg-n-weak" />
        </li>
      </ol>
      <p class="mb-0 ms-auto text-sm text-n-slate-11 md:hidden">
        {{
          $t('HOME.GUIDED.STEP_OF', {
            current: currentIndex + 1,
            total: GUIDED_STEPS.length,
          })
        }}
      </p>
      <Button
        icon="i-lucide-x"
        variant="ghost"
        color="slate"
        size="sm"
        :aria-label="$t('HOME.GUIDED.CLOSE')"
        @click="closeSetup"
      />
    </header>

    <div
      class="mx-auto grid w-full max-w-[72rem] flex-1 gap-8 px-4 py-8 sm:px-8 sm:py-10 lg:grid-cols-2 lg:items-center lg:gap-12"
    >
      <section
        class="flex w-full max-w-[30rem] flex-col gap-6 lg:justify-self-center"
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
          ref="stepView"
          :guided="guided"
          v-bind="stepProps"
          @open="openStep"
          @ask="chat.ask"
        />

        <p v-if="actionError" role="alert" class="mb-0 text-sm text-n-ruby-11">
          {{ actionError }}
        </p>

        <footer class="flex flex-wrap items-center gap-3 pt-2">
          <Button
            :label="primaryLabel"
            :is-loading="isBusy"
            @click="continueStep"
          />
          <Button
            v-if="!stepState(currentStep)?.done"
            :label="$t('HOME.GUIDED.SKIP')"
            variant="faded"
            color="slate"
            @click="skipStep"
          />
          <Button
            v-if="currentIndex > 0"
            :label="$t('HOME.GUIDED.BACK')"
            icon="i-lucide-arrow-left"
            variant="ghost"
            color="slate"
            class="ms-auto"
            @click="goBack"
          />
        </footer>
      </section>

      <aside
        class="items-center justify-center rounded-[1.75rem] bg-[image:var(--co-hero-bg)] p-6 sm:p-10 lg:flex lg:min-h-[34rem]"
        :class="showChat ? 'flex' : 'hidden'"
      >
        <div v-if="showChat" class="flex w-full max-w-[24rem] flex-col gap-3">
          <SetupChat
            :messages="chat.messages"
            :is-sending="chat.isSending"
            @ask="chat.ask"
          />
          <p class="mb-0 text-center text-xs text-white/85">
            {{ $t('HOME.GUIDED.CHAT.TEST_ONLY') }}
          </p>
        </div>
        <div
          v-else
          class="flex w-full max-w-[20rem] flex-col items-center gap-4"
        >
          <Icon icon="i-lucide-globe" class="size-12 text-white/90" />
          <p
            v-if="websiteHost"
            class="mb-0 break-all text-center font-display text-xl text-white"
          >
            {{ websiteHost }}
          </p>
          <LearnedBanner
            v-if="guided.state?.website_source"
            on-brand
            class="w-full"
            :learned="guided.learned"
            :total="guided.total"
            :reading="guided.isLearning || guided.isImporting"
          />
        </div>
      </aside>
    </div>
  </div>
</template>

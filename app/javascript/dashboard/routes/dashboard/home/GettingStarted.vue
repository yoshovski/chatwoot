<script setup>
import { computed, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import CaptainHomeAPI from 'dashboard/api/captain/home';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import PageFrame from 'dashboard/components-next/kit/PageFrame.vue';
import PageHeader from 'dashboard/components-next/kit/PageHeader.vue';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';
import CardError from './components/CardError.vue';
import SetupProgressCard from './components/SetupProgressCard.vue';
import { useHomeSetupProgress } from './useHomeSetupProgress';
import { setupStepText } from './homeSetup';

const route = useRoute();
const { t } = useI18n();
const summary = ref(null);
const error = ref(false);
const { run } = useAbortableRequest();
const { progress, skip, unskip } = useHomeSetupProgress(summary);
const dashboard = { name: 'account_home' };
const nextStep = computed(() =>
  progress.value.steps.find(step => !step.done && !step.skipped)
);
const nextStepText = computed(() => setupStepText(t)[nextStep.value?.key]);
const setupComplete = computed(
  () => progress.value.doneCount === progress.value.total
);

const stepRoute = step => {
  if (step.guided) {
    return {
      name: 'account_home_setup',
      params: { step: step.key },
      query: { from: 'getting-started' },
    };
  }
  return step.key === 'mailbox'
    ? { name: 'settings_inboxes_page_channel', params: { sub_page: 'email' } }
    : { name: step.route };
};
const load = async () => {
  error.value = false;
  try {
    const response = await run(signal => CaptainHomeAPI.get({ signal }));
    if (response) summary.value = response.data;
  } catch {
    error.value = true;
  }
};

watch(
  () => route.params.accountId,
  () => {
    summary.value = null;
    load();
  },
  { immediate: true }
);
</script>

<template>
  <PageFrame size="wide">
    <template #header>
      <PageHeader
        :title="$t('HOME.GETTING_STARTED.TITLE')"
        :description="$t('HOME.GETTING_STARTED.DESCRIPTION')"
      >
        <template #action>
          <RouterLink
            :to="dashboard"
            class="inline-flex min-h-9 items-center gap-1.5 rounded-lg border border-n-weak px-3 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2"
          >
            <Icon icon="i-lucide-arrow-left" class="size-4" />
            {{ $t('HOME.GETTING_STARTED.BACK') }}
          </RouterLink>
        </template>
      </PageHeader>
    </template>

    <CardError v-if="error" @retry="load" />
    <div
      v-else-if="!summary"
      class="h-56 animate-pulse rounded-card bg-n-alpha-2"
      aria-busy="true"
    />
    <div v-else class="grid grid-cols-1 items-start gap-4 lg:grid-cols-3">
      <SetupProgressCard
        class="lg:col-span-2"
        grouped
        :progress="progress"
        :step-route="stepRoute"
        @skip="skip"
        @unskip="unskip"
      />
      <SectionCard v-if="nextStep" :title="$t('HOME.GETTING_STARTED.NEXT')">
        <div class="flex items-start gap-3">
          <span
            class="grid size-9 shrink-0 place-items-center rounded-md bg-n-blue-3 text-n-blue-11"
          >
            <Icon
              :icon="
                nextStep.guided ? 'i-lucide-list-checks' : 'i-lucide-settings'
              "
              class="size-5"
            />
          </span>
          <div class="min-w-0">
            <p class="m-0 font-semibold text-n-slate-12">
              {{ nextStepText.title }}
            </p>
            <p class="mb-0 mt-1 text-sm text-n-slate-11">
              {{ nextStepText.hint }}
            </p>
            <p
              v-if="!nextStep.guided"
              class="mb-0 mt-2 text-xs text-n-slate-11"
            >
              {{ $t('HOME.GETTING_STARTED.OPTIONAL') }}
            </p>
          </div>
        </div>
        <RouterLink
          :to="stepRoute(nextStep)"
          class="inline-flex min-h-9 w-fit items-center gap-1.5 rounded-lg bg-n-brand px-3 text-sm font-medium text-white hover:brightness-110"
        >
          {{ $t('HOME.GETTING_STARTED.CONTINUE') }}
          <Icon icon="i-lucide-arrow-right" class="size-4" />
        </RouterLink>
      </SectionCard>
      <SectionCard
        v-else
        :title="
          setupComplete
            ? t('HOME.GETTING_STARTED.COMPLETE')
            : t('HOME.GETTING_STARTED.REVIEWED')
        "
      >
        <p class="m-0 text-sm text-n-slate-11">
          {{
            setupComplete
              ? t('HOME.GETTING_STARTED.COMPLETE_HINT')
              : t('HOME.GETTING_STARTED.REVIEWED_HINT')
          }}
        </p>
      </SectionCard>
    </div>
  </PageFrame>
</template>

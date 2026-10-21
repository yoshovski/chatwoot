<script setup>
import { computed, ref, nextTick, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import Button from 'next/button/Button.vue';
import Policy from 'dashboard/components/policy.vue';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useAccount } from 'dashboard/composables/useAccount';

import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import CaptainPaywall from 'dashboard/components-next/captain/pageComponents/Paywall.vue';
import CreateAssistantDialog from 'dashboard/components-next/captain/pageComponents/assistant/CreateAssistantDialog.vue';
import FeatureSpotlightPopover from 'dashboard/components-next/feature-spotlight/FeatureSpotlightPopover.vue';

const { isOnChatwootCloud, accountScopedRoute } = useAccount();
const store = useStore();
const assistants = useMapGetter('captainAssistants/getRecords');
onMounted(() => store.dispatch('captainAssistants/get'));

const dialogType = ref('');
const uiFlags = useMapGetter('captainAssistants/getUIFlags');
const isFetching = computed(() => uiFlags.value.fetchingList);

const selectedAssistant = ref(null);
const createAssistantDialog = ref(null);
const router = useRouter();

const handleCreate = () => {
  dialogType.value = 'create';
  nextTick(() => createAssistantDialog.value.dialogRef.open());
};

const handleCreateClose = () => {
  dialogType.value = '';
  selectedAssistant.value = null;
};

const handleAfterCreate = newAssistant => {
  // Navigate directly to documents page with the new assistant ID
  if (newAssistant?.id) {
    router.push({
      name: 'captain_assistants_overview_index',
      params: {
        accountId: router.currentRoute.value.params.accountId,
        assistantId: newAssistant.id,
      },
    });
  }
};
</script>

<template>
  <PageLayout
    :header-title="$t('PLATFORM_NAV.AI_AGENTS')"
    :button-label="$t('CAPTAIN.ASSISTANT_SWITCHER.NEW_ASSISTANT')"
    :button-policy="['administrator']"
    :show-pagination-footer="false"
    :is-fetching="isFetching"
    :feature-flag="FEATURE_FLAGS.CAPTAIN"
    :is-empty="!assistants.length"
    @click="handleCreate"
  >
    <template #knowMore>
      <FeatureSpotlightPopover
        :button-label="$t('CAPTAIN.HEADER_KNOW_MORE')"
        :title="$t('CAPTAIN.ASSISTANTS.EMPTY_STATE.FEATURE_SPOTLIGHT.TITLE')"
        :note="$t('CAPTAIN.ASSISTANTS.EMPTY_STATE.FEATURE_SPOTLIGHT.NOTE')"
        :hide-actions="!isOnChatwootCloud"
        fallback-thumbnail="/assets/images/dashboard/captain/assistant-popover-light.svg"
        fallback-thumbnail-dark="/assets/images/dashboard/captain/assistant-popover-dark.svg"
        learn-more-url="https://chwt.app/captain-assistant"
      />
    </template>
    <template #emptyState>
      <div
        class="flex min-h-80 flex-col items-center justify-center gap-4 text-center"
      >
        <h2 class="text-xl font-semibold text-n-slate-12">
          {{ $t('PLATFORM_NAV.NO_AGENT') }}
        </h2>
        <p class="max-w-md text-sm text-n-slate-11">
          {{ $t('PLATFORM_NAV.NO_AGENT_DESCRIPTION') }}
        </p>
        <Policy :permissions="['administrator']">
          <Button
            :label="$t('CAPTAIN.ASSISTANT_SWITCHER.NEW_ASSISTANT')"
            icon="i-lucide-plus"
            @click="handleCreate"
          />
        </Policy>
      </div>
    </template>
    <template #body>
      <ul
        class="m-0 flex list-none flex-col divide-y divide-n-weak rounded-xl border border-n-weak p-0"
      >
        <li
          v-for="assistant in assistants"
          :key="assistant.id"
          class="flex flex-wrap items-center justify-between gap-4 p-5"
        >
          <span class="font-medium text-n-slate-12">{{ assistant.name }}</span>
          <RouterLink
            :to="
              accountScopedRoute('captain_assistants_overview_index', {
                assistantId: assistant.id,
              })
            "
            class="text-sm text-n-blue-text hover:underline"
          >
            {{ $t('PLATFORM_NAV.MANAGE_AGENT') }}
          </RouterLink>
        </li>
      </ul>
    </template>

    <template #paywall>
      <CaptainPaywall />
    </template>

    <CreateAssistantDialog
      v-if="dialogType"
      ref="createAssistantDialog"
      :type="dialogType"
      :selected-assistant="selectedAssistant"
      @close="handleCreateClose"
      @created="handleAfterCreate"
    />
  </PageLayout>
</template>

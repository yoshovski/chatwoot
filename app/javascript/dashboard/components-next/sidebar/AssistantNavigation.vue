<script setup>
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { useAccount } from 'dashboard/composables/useAccount';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import Button from 'next/button/Button.vue';
import CreateAssistantDialog from 'next/captain/pageComponents/assistant/CreateAssistantDialog.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const { checkPermissions, shouldShowPaywall } = usePolicy();
const { currentAccount } = useAccount();
const assistants = useMapGetter('captainAssistants/getRecords');
const dialog = ref(null);
const selectedId = computed(() => route.params.assistantId || '');
const canCreate = computed(
  () =>
    checkPermissions(['administrator']) &&
    Boolean(currentAccount.value?.features?.captain_integration) &&
    !shouldShowPaywall(FEATURE_FLAGS.CAPTAIN)
);
const openAgent = id => {
  const name = route.params.assistantId
    ? route.name
    : 'captain_assistants_overview_index';
  router.push({
    name,
    params: { accountId: route.params.accountId, assistantId: id },
  });
};
const created = assistant => {
  router.push({
    name: 'captain_assistants_overview_index',
    params: { accountId: route.params.accountId, assistantId: assistant.id },
  });
};
watch(
  () => route.params.accountId,
  () => store.dispatch('captainAssistants/get'),
  { immediate: true }
);
</script>

<template>
  <div class="flex flex-col gap-3 px-4 py-3">
    <label
      v-if="assistants.length"
      class="flex flex-col gap-1 text-xs text-n-slate-11"
    >
      {{ t('PLATFORM_NAV.AI_AGENT') }}
      <select
        :value="selectedId"
        class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2 text-sm font-medium text-n-slate-12"
        @change="openAgent($event.target.value)"
      >
        <option v-if="!selectedId" value="" disabled>
          {{ t('PLATFORM_NAV.SELECT_AGENT') }}
        </option>
        <option
          v-for="assistant in assistants"
          :key="assistant.id"
          :value="assistant.id"
        >
          {{ assistant.name }}
        </option>
      </select>
    </label>
    <Button
      v-if="canCreate"
      :label="t('CAPTAIN.ASSISTANT_SWITCHER.NEW_ASSISTANT')"
      icon="i-lucide-plus"
      size="sm"
      class="w-full"
      @click="dialog.dialogRef.open()"
    />
    <CreateAssistantDialog v-if="canCreate" ref="dialog" @created="created" />
  </div>
</template>

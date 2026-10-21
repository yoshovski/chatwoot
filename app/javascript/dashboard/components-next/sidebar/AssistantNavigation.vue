<script setup>
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { useAccount } from 'dashboard/composables/useAccount';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import Button from 'next/button/Button.vue';
import Avatar from 'next/avatar/Avatar.vue';
import Icon from 'next/icon/Icon.vue';
import {
  DropdownContainer,
  DropdownBody,
  DropdownItem,
} from 'next/dropdown-menu/base';
import CreateAssistantDialog from 'next/captain/pageComponents/assistant/CreateAssistantDialog.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const { checkPermissions, shouldShowPaywall } = usePolicy();
const { currentAccount } = useAccount();
const assistants = useMapGetter('captainAssistants/getRecords');
const dialog = ref(null);
const selectedId = computed(() => String(route.params.assistantId || ''));
const selectedAssistant = computed(() =>
  assistants.value.find(assistant => String(assistant.id) === selectedId.value)
);
const canCreate = computed(
  () =>
    checkPermissions(['administrator']) &&
    Boolean(currentAccount.value?.features?.captain_integration) &&
    !shouldShowPaywall(FEATURE_FLAGS.CAPTAIN)
);
const openAgent = id => {
  if (String(id) === selectedId.value) return;
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
  <div class="flex flex-col gap-2 px-4 pb-3 pt-1">
    <DropdownContainer v-if="assistants.length">
      <template #trigger="{ toggle, isOpen }">
        <button
          type="button"
          :aria-label="t('PLATFORM_NAV.AI_AGENT')"
          aria-haspopup="listbox"
          :aria-expanded="isOpen"
          class="flex h-10 w-full items-center gap-2 rounded-lg border border-n-weak bg-n-alpha-1 px-2.5 text-start transition-colors hover:border-n-strong"
          :class="{ 'border-n-brand': isOpen }"
          @click="toggle"
        >
          <Avatar
            v-if="selectedAssistant"
            :src="selectedAssistant.avatar_url"
            :name="selectedAssistant.name"
            :size="20"
            icon-name="i-lucide-bot"
            rounded-full
          />
          <Icon v-else icon="i-lucide-bot" class="size-5 text-n-slate-10" />
          <span
            class="min-w-0 flex-1 truncate text-sm font-medium"
            :class="selectedAssistant ? 'text-n-slate-12' : 'text-n-slate-10'"
          >
            {{ selectedAssistant?.name || t('PLATFORM_NAV.SELECT_AGENT') }}
          </span>
          <Icon
            :icon="isOpen ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'"
            class="size-4 shrink-0 text-n-slate-10"
          />
        </button>
      </template>
      <DropdownBody class="z-50 w-56 max-h-80 overflow-y-auto">
        <DropdownItem
          v-for="assistant in assistants"
          :key="assistant.id"
          :click="() => openAgent(assistant.id)"
        >
          <template #icon>
            <Avatar
              :src="assistant.avatar_url"
              :name="assistant.name"
              :size="20"
              icon-name="i-lucide-bot"
              rounded-full
            />
          </template>
          <template #label>
            <span class="min-w-0 flex-1 truncate">{{ assistant.name }}</span>
            <Icon
              v-if="String(assistant.id) === selectedId"
              icon="i-lucide-check"
              class="size-4 shrink-0 text-n-teal-11"
            />
          </template>
        </DropdownItem>
        <DropdownItem
          v-if="canCreate"
          class="border-t border-n-weak"
          :click="() => dialog.dialogRef.open()"
        >
          <template #icon>
            <Icon icon="i-lucide-plus" class="size-4 text-n-slate-10" />
          </template>
          <template #label>
            <span class="min-w-0 flex-1 truncate font-medium">
              {{ t('CAPTAIN.ASSISTANT_SWITCHER.NEW_ASSISTANT') }}
            </span>
          </template>
        </DropdownItem>
      </DropdownBody>
    </DropdownContainer>
    <Button
      v-if="canCreate && !assistants.length"
      :label="t('CAPTAIN.ASSISTANT_SWITCHER.NEW_ASSISTANT')"
      icon="i-lucide-plus"
      size="sm"
      variant="faded"
      color="slate"
      class="w-full"
      @click="dialog.dialogRef.open()"
    />
    <CreateAssistantDialog v-if="canCreate" ref="dialog" @created="created" />
  </div>
</template>

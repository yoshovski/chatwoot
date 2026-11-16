<script setup>
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys -- Capture state is a fixed local enum within LEADS.CAPTURE. */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useAccount } from 'dashboard/composables/useAccount';
import AssistantsAPI from 'dashboard/api/captain/assistant';
import Button from 'dashboard/components-next/button/Button.vue';
import CreateAssistantDialog from 'dashboard/components-next/captain/pageComponents/assistant/CreateAssistantDialog.vue';

const { t } = useI18n();
const { isAdmin } = useAdmin();
const { shouldShowPaywall } = usePolicy();
const captureUnavailable = computed(() =>
  shouldShowPaywall(FEATURE_FLAGS.CAPTAIN)
);
const { accountScopedRoute } = useAccount();
const router = useRouter();
const assistants = ref([]);
const selectedId = ref('');
const loading = ref(true);
const error = ref(false);
const createDialog = ref(null);
const load = async () => {
  if (!isAdmin.value || captureUnavailable.value) {
    loading.value = false;
    return;
  }
  loading.value = true;
  error.value = false;
  try {
    const { data } = await AssistantsAPI.get();
    assistants.value = data.payload;
    selectedId.value =
      assistants.value.length === 1 ? assistants.value[0].id : '';
  } catch {
    error.value = true;
  } finally {
    loading.value = false;
  }
};
onMounted(load);
const selected = computed(() =>
  assistants.value.find(item => item.id === selectedId.value)
);
const captureState = computed(() => {
  if (!selected.value)
    return assistants.value.length ? 'CHOOSE_HELP' : 'CREATE_HELP';
  if (selected.value.config?.leads_enabled) return 'ENABLED';
  return selected.value.config?.lead_types?.length ? 'PAUSED' : 'UNCONFIGURED';
});
const openSetup = assistant =>
  router.push(
    accountScopedRoute('captain_assistants_settings_leads_index', {
      assistantId: assistant.id,
    })
  );
</script>

<template>
  <div class="flex w-full max-w-lg flex-col items-center gap-3">
    <p v-if="!isAdmin" class="m-0 text-sm text-n-slate-11">
      {{ t('LEADS.CAPTURE.NO_ACCESS') }}
    </p>
    <p v-else-if="captureUnavailable" class="m-0 text-sm text-n-slate-11">
      {{ t('LEADS.CAPTURE.UNAVAILABLE') }}
    </p>
    <p v-else-if="loading" class="m-0 text-sm text-n-slate-11" role="status">
      {{ t('LEADS.CAPTURE.LOADING') }}
    </p>
    <div
      v-else-if="error"
      class="flex flex-col items-center gap-3"
      role="alert"
    >
      <p class="m-0 text-sm text-n-ruby-11">{{ t('LEADS.CAPTURE.ERROR') }}</p>
      <Button :label="t('LEADS.RETRY')" size="sm" @click="load" />
    </div>
    <template v-else>
      <label
        v-if="assistants.length > 1"
        class="m-0 flex w-full flex-col gap-2 text-start text-sm text-n-slate-12"
      >
        {{ t('LEADS.CAPTURE.CHOOSE') }}
        <select
          v-model="selectedId"
          class="m-0 w-full rounded-lg border border-n-weak bg-n-solid-1 p-2 text-sm text-n-slate-12"
        >
          <option disabled value="">{{ t('LEADS.CAPTURE.CHOOSE') }}</option>
          <option
            v-for="assistant in assistants"
            :key="assistant.id"
            :value="assistant.id"
          >
            {{ assistant.name }}
          </option>
        </select>
      </label>
      <!-- Capture state comes from the saved agent config; this does not claim channel/scenario readiness. -->
      <p class="m-0 text-sm text-n-slate-11">
        {{ t(`LEADS.CAPTURE.${captureState}`) }}
      </p>
      <Button
        v-if="assistants.length"
        :label="t('LEADS.CAPTURE.OPEN_SETUP')"
        size="sm"
        :disabled="!selected"
        @click="openSetup(selected)"
      />
      <Button
        v-else
        :label="t('LEADS.CAPTURE.CREATE')"
        size="sm"
        @click="createDialog.dialogRef.open()"
      />
      <CreateAssistantDialog
        v-if="!assistants.length"
        ref="createDialog"
        type="create"
        @created="openSetup"
      />
    </template>
  </div>
</template>

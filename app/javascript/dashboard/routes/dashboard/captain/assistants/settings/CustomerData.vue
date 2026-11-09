<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAssistantSettings } from './useAssistantSettings';
import Banner from 'dashboard/components-next/banner/Banner.vue';
import SettingsPageLayout from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsPageLayout.vue';
import SettingsCard from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsCard.vue';
import SettingsSwitchRow from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsSwitchRow.vue';
import SettingsSaveBar from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsSaveBar.vue';

// Data permissions in one place: reading contact details (was under Boundaries) and
// remembering returning customers (was under After chat).
const { t } = useI18n();
const store = useStore();
const { assistant, assistantId, updateAssistant } = useAssistantSettings();
const inboxes = useMapGetter('captainInboxes/getRecords');
const U = 'CAPTAIN.AGENT_UX.CUSTOMER_DATA';

watch(
  assistantId,
  id => {
    if (id) store.dispatch('captainInboxes/get', { assistantId: id });
  },
  { immediate: true }
);

const name = computed(() => assistant.value?.name || '');
const saved = computed(() => assistant.value?.config || {});
const draft = ref({});
const field = key =>
  computed({
    get: () => Boolean({ ...saved.value, ...draft.value }[key]),
    set: value => {
      draft.value = { ...draft.value, [key]: value };
    },
  });
const contactAccess = field('feature_contact_attributes');
const memories = field('feature_memory');

const isDirty = computed(() =>
  Object.entries(draft.value).some(
    ([key, value]) => Boolean(saved.value[key]) !== value
  )
);
const isSaving = ref(false);
const save = async () => {
  isSaving.value = true;
  const ok = await updateAssistant({
    config: { ...saved.value, ...draft.value },
  });
  isSaving.value = false;
  if (ok) draft.value = {};
};
const discard = () => {
  draft.value = {};
};
watch(assistantId, discard);

const continuityOffInbox = computed(() =>
  (inboxes.value || []).find(
    inbox =>
      inbox.channel_type === 'Channel::WebWidget' && !inbox.continuity_via_email
  )
);
</script>

<template>
  <SettingsPageLayout :heading="t('CAPTAIN.AGENT_UX.SECTIONS.BEHAVIOR')">
    <div class="flex flex-col max-w-3xl gap-4">
      <div class="flex flex-col gap-1">
        <h3 class="m-0 text-base font-semibold text-n-slate-12">
          {{ t(`${U}.TITLE`, { name }) }}
        </h3>
        <p class="m-0 text-sm text-n-slate-11">{{ t(`${U}.DESC`) }}</p>
      </div>
      <SettingsCard>
        <SettingsSwitchRow
          v-model="contactAccess"
          :title="t(`${U}.CONTACT_TITLE`)"
          :description="t(`${U}.CONTACT_DESC`)"
        />
        <SettingsSwitchRow
          v-model="memories"
          :title="t(`${U}.MEMORY_TITLE`)"
          :description="t(`${U}.MEMORY_DESC`, { name })"
        />
      </SettingsCard>
      <Banner v-if="memories && continuityOffInbox" color="amber">
        {{ t(`${U}.CONTINUITY_HINT`, { inbox: continuityOffInbox.name }) }}
      </Banner>
      <SettingsSaveBar
        :is-dirty="isDirty"
        :is-saving="isSaving"
        @save="save"
        @discard="discard"
      />
    </div>
  </SettingsPageLayout>
</template>

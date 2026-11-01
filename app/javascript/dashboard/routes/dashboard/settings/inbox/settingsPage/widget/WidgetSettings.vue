<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useEventListener } from '@vueuse/core';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { LocalStorage } from 'shared/helpers/localStorage';
import { buildInstallSnippet } from 'dashboard/helper/widgetScript';
import CaptainAssistantAPI from 'dashboard/api/captain/assistant';
import CaptainInboxesAPI from 'dashboard/api/captain/inboxes';
import GreetingsEditor from 'shared/components/GreetingsEditor.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import SettingsSaveBar from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsSaveBar.vue';
import WidgetLivePreview from 'dashboard/components-next/Inbox/WidgetLivePreview.vue';
import WidgetEssentials from './WidgetEssentials.vue';
import WidgetInstallation from './WidgetInstallation.vue';
import WidgetAiAgentCard from './WidgetAiAgentCard.vue';
import WidgetAdvanced from './WidgetAdvanced.vue';
import {
  buildPreviewConfig,
  buildWidgetForm,
  buildWidgetPayload,
  pickScriptSettings,
} from './widgetSettingsForm';

// The web widget's settings tab: essentials first, the rest under Advanced, and the real widget as a live preview.
const props = defineProps({
  inbox: { type: Object, required: true },
  inboxIcon: { type: String, default: '' },
});

const emit = defineEmits(['openPreChatForm']);

const { t } = useI18n();
const store = useStore();
const { currentAccount, isCloudFeatureEnabled } = useAccount();
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);
const isOnChatwootCloud = useMapGetter('globalConfig/isOnChatwootCloud');
const portals = useMapGetter('portals/allPortals');
const uiFlags = useMapGetter('inboxes/getUIFlags');

const form = ref({});
const savedSnapshot = ref('');
const avatarFile = ref(null);
const aiAgent = ref(null);
const isPreviewOpen = ref(false);
const showNameError = ref(false);

const storageKey = computed(
  () => `${LOCAL_STORAGE_KEYS.WIDGET_BUILDER}${props.inbox.id}`
);

const resetForm = () => {
  form.value = buildWidgetForm(
    props.inbox,
    LocalStorage.get(storageKey.value) || {}
  );
  avatarFile.value = null;
  showNameError.value = false;
  savedSnapshot.value = JSON.stringify(form.value);
};

const isDirty = computed(
  () => !!avatarFile.value || JSON.stringify(form.value) !== savedSnapshot.value
);

const savedScriptSettings = computed(() =>
  pickScriptSettings(JSON.parse(savedSnapshot.value || '{}'))
);
const scriptSettings = computed(() => pickScriptSettings(form.value));
const snippet = computed(() =>
  buildInstallSnippet(props.inbox.web_widget_script, scriptSettings.value)
);
const hasUnsavedSnippet = computed(
  () =>
    JSON.stringify(scriptSettings.value) !==
    JSON.stringify(savedScriptSettings.value)
);

const isInboundEmailEnabled = computed(() =>
  isFeatureEnabledonAccount.value(
    currentAccount.value.id,
    FEATURE_FLAGS.INBOUND_EMAILS
  )
);
const showContinuityToggle = computed(
  () => isInboundEmailEnabled.value || isOnChatwootCloud.value
);
const isContinuityDisabled = computed(
  () => isOnChatwootCloud.value && !isInboundEmailEnabled.value
);
const continuityDescription = computed(() =>
  isContinuityDisabled.value
    ? t('INBOX_MGMT.SETTINGS_POPUP.ENABLE_CONTINUITY_VIA_EMAIL_DISABLED_TEXT')
    : t('INBOX_MGMT.SETTINGS_POPUP.ENABLE_CONTINUITY_VIA_EMAIL_SUB_TEXT')
);

const nameError = computed(() =>
  showNameError.value && !form.value.name.trim()
    ? t('INBOX_MGMT.ADD.CHANNEL_NAME.ERROR')
    : ''
);

const previewConfig = computed(() =>
  buildPreviewConfig(form.value, { locale: currentAccount.value.locale })
);

// Captain has no inbox → agent lookup, so find the agent whose connected inboxes include this one.
const loadAiAgent = async () => {
  aiAgent.value = null;
  if (!isCloudFeatureEnabled(FEATURE_FLAGS.CAPTAIN)) return;

  const inboxId = props.inbox.id;
  const { data } = await CaptainAssistantAPI.get();
  const connections = await Promise.all(
    data.payload.map(async assistant => {
      const { data: inboxes } = await CaptainInboxesAPI.get({
        assistantId: assistant.id,
      });
      return inboxes.payload.some(inbox => inbox.id === inboxId)
        ? assistant
        : null;
    })
  );
  if (props.inbox.id === inboxId) aiAgent.value = connections.find(Boolean);
};

const save = async () => {
  if (!form.value.name.trim()) {
    showNameError.value = true;
    return;
  }
  const payload = buildWidgetPayload(form.value, {
    inboxId: props.inbox.id,
    portals: portals.value,
    canEmailContinuity: isInboundEmailEnabled.value,
  });
  if (avatarFile.value) payload.avatar = avatarFile.value;

  try {
    await store.dispatch('inboxes/updateInbox', payload);
    LocalStorage.set(storageKey.value, scriptSettings.value);
    resetForm();
    useAlert(t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(error.message || t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
  }
};

const uploadAvatar = ({ file, url }) => {
  avatarFile.value = file;
  form.value.avatarUrl = url;
};

const deleteAvatar = async () => {
  try {
    await store.dispatch('inboxes/deleteInboxAvatar', props.inbox.id);
    avatarFile.value = null;
    form.value.avatarUrl = '';
    useAlert(t('INBOX_MGMT.DELETE.API.AVATAR_SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(error.message || t('INBOX_MGMT.DELETE.API.AVATAR_ERROR_MESSAGE'));
  }
};

// Leaving the page is guarded by the save bar; closing the tab is guarded here.
useEventListener(window, 'beforeunload', event => {
  if (isDirty.value) event.preventDefault();
});

watch(
  () => props.inbox.id,
  () => {
    resetForm();
    loadAiAgent();
  }
);

resetForm();
onMounted(loadAiAgent);
</script>

<template>
  <div
    class="grid items-start gap-6 lg:gap-8 lg:grid-cols-[minmax(0,1fr)_minmax(0,26rem)]"
  >
    <div class="flex flex-col min-w-0 gap-6">
      <WidgetEssentials
        v-model:form="form"
        :inbox-icon="inboxIcon"
        :name-error="nameError"
        @upload-avatar="uploadAvatar"
        @delete-avatar="deleteAvatar"
      />

      <WidgetAiAgentCard v-if="aiAgent" :assistant="aiAgent" />
      <SettingsToggleSection
        v-else
        v-model="form.greetingEnabled"
        :header="
          $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_TOGGLE.LABEL')
        "
        :description="
          $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_TOGGLE.HELP_TEXT')
        "
        class="bg-n-solid-1"
      >
        <template v-if="form.greetingEnabled" #editor>
          <GreetingsEditor
            v-model="form.greetingMessage"
            :label="
              $t(
                'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_MESSAGE.LABEL'
              )
            "
            :placeholder="
              $t(
                'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_MESSAGE.PLACEHOLDER'
              )
            "
            richtext
          />
        </template>
      </SettingsToggleSection>

      <WidgetInstallation
        v-model:form="form"
        :inbox-id="inbox.id"
        :snippet="snippet"
        :has-unsaved-snippet="hasUnsavedSnippet"
      />

      <WidgetAdvanced
        v-model:form="form"
        :inbox="inbox"
        :portals="portals"
        :show-continuity-toggle="showContinuityToggle"
        :is-continuity-disabled="isContinuityDisabled"
        :continuity-description="continuityDescription"
        @open-pre-chat-form="emit('openPreChatForm')"
      />

      <SettingsSaveBar
        :is-dirty="isDirty"
        :is-saving="uiFlags.isUpdating"
        @save="save"
        @discard="resetForm"
      />
    </div>

    <aside class="flex flex-col min-w-0 gap-3 lg:sticky lg:top-4">
      <Button
        class="lg:hidden self-start"
        :label="
          isPreviewOpen
            ? $t('INBOX_MGMT.WIDGET_SETTINGS.PREVIEW_TOGGLE.HIDE')
            : $t('INBOX_MGMT.WIDGET_SETTINGS.PREVIEW_TOGGLE.SHOW')
        "
        :icon="isPreviewOpen ? 'i-lucide-eye-off' : 'i-lucide-eye'"
        :aria-expanded="isPreviewOpen"
        variant="faded"
        color="slate"
        size="sm"
        @click="isPreviewOpen = !isPreviewOpen"
      />
      <WidgetLivePreview
        :class="{ 'hidden lg:flex': !isPreviewOpen }"
        :inbox-id="inbox.id"
        :config="previewConfig"
      />
    </aside>
  </div>
</template>

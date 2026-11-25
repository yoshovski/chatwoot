<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { onBeforeRouteUpdate } from 'vue-router';
import { useEventListener } from '@vueuse/core';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { LocalStorage } from 'shared/helpers/localStorage';
import { buildInstallSnippet } from 'dashboard/helper/widgetScript';
import GreetingsEditor from 'shared/components/GreetingsEditor.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import SettingsSaveBar from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsSaveBar.vue';
import WidgetLivePreview from 'dashboard/components-next/Inbox/WidgetLivePreview.vue';
import WidgetEssentials from './WidgetEssentials.vue';
import WidgetInstallation from './WidgetInstallation.vue';
import WidgetAiAgentCard from './WidgetAiAgentCard.vue';
import WidgetBehavior from './WidgetBehavior.vue';
import WidgetSecurity from './WidgetSecurity.vue';
import WidgetWelcome from './WidgetWelcome.vue';
import {
  buildPreviewConfig,
  buildWidgetForm,
  buildWidgetPayload,
  pickScriptSettings,
} from './widgetSettingsForm';

const props = defineProps({
  inbox: { type: Object, required: true },
  section: { type: String, default: 'appearance' },
  hasCaptain: { type: Boolean, default: false },
});

const emit = defineEmits(['openAppearance', 'openInstallation']);

const { t } = useI18n();
const store = useStore();
const { currentAccount } = useAccount();
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);
const isOnChatwootCloud = useMapGetter('globalConfig/isOnChatwootCloud');
const portals = useMapGetter('portals/allPortals');
const uiFlags = useMapGetter('inboxes/getUIFlags');

const form = ref({});
const savedSnapshot = ref('');
const avatarFile = ref(null);
const aiAgent = computed(() => props.inbox.captain_assistant);
const isPreviewOpen = ref(false);
const showNameError = ref(false);
const livePreview = ref(null);
const selectedView = ref('home');

const hasPreview = computed(() =>
  ['appearance', 'welcome', 'conversation'].includes(props.section)
);

const isWidgetSection = computed(
  () => hasPreview.value || ['installation', 'security'].includes(props.section)
);

const previewViews = computed(() => [
  { value: 'home', label: t('INBOX_MGMT.WIDGET_PREVIEW.VIEWS.HOME') },
  {
    value: 'conversation',
    label: t('INBOX_MGMT.WIDGET_PREVIEW.VIEWS.CONVERSATION'),
  },
  { value: 'launcher', label: t('INBOX_MGMT.WEBSITE_SETTINGS.LAUNCHER') },
]);

const selectPreviewView = view => {
  selectedView.value = view;
  livePreview.value?.setView(view);
};

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

const save = async () => {
  if (!form.value.name.trim()) {
    showNameError.value = true;
    emit('openAppearance');
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

onBeforeRouteUpdate((to, from) => {
  const inboxChanged =
    to.params.inboxId !== from.params.inboxId ||
    to.params.accountId !== from.params.accountId;
  if (!inboxChanged || !isDirty.value) return true;
  // eslint-disable-next-line no-alert
  return window.confirm(t('CAPTAIN.ASSISTANTS.SETTINGS.SAVE_BAR.LEAVE'));
});

watch(() => props.inbox.id, resetForm);
watch(
  () => props.section,
  section => {
    if (section === 'conversation') selectPreviewView('conversation');
    else if (section === 'welcome') selectPreviewView('home');
  }
);

onMounted(() => {
  if (props.section === 'conversation') selectPreviewView('conversation');
});
resetForm();
</script>

<template>
  <div
    class="flex min-w-0 flex-col gap-4"
    :class="{ 'max-w-3xl': !hasPreview }"
  >
    <div
      v-if="isDirty && !isWidgetSection"
      role="region"
      :aria-label="$t('INBOX_MGMT.WEBSITE_SETTINGS.UNSAVED_WIDGET')"
      class="flex max-w-3xl flex-wrap items-center justify-between gap-2 rounded-xl border border-n-amber-6 bg-n-amber-2 px-4 py-2 text-sm"
    >
      <span class="text-n-slate-12">{{
        $t('INBOX_MGMT.WEBSITE_SETTINGS.UNSAVED_WIDGET')
      }}</span>
      <Button
        :label="$t('INBOX_MGMT.WEBSITE_SETTINGS.REVIEW_WIDGET')"
        color="slate"
        variant="ghost"
        size="sm"
        @click="$emit('openAppearance')"
      />
    </div>
    <div
      class="grid min-w-0 items-start gap-5"
      :class="{
        'xl:grid-cols-[minmax(0,1fr)_minmax(17rem,21rem)]': hasPreview,
      }"
    >
      <aside
        v-show="hasPreview"
        class="row-start-1 flex min-w-0 flex-col gap-3 xl:sticky xl:top-4 xl:col-start-2"
      >
        <Button
          class="self-start xl:hidden"
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
        <div
          class="rounded-card bg-n-solid-2 p-3 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
          :class="{ 'hidden xl:block': !isPreviewOpen }"
        >
          <div class="mb-3 flex items-center gap-2 px-1">
            <span
              class="i-lucide-monitor size-4 text-n-slate-11"
              aria-hidden="true"
            />
            <h3 class="m-0 text-heading-3 text-n-slate-12">
              {{ $t('INBOX_MGMT.WIDGET_PREVIEW.TITLE') }}
            </h3>
          </div>
          <div
            class="mb-3 grid grid-cols-3 gap-0.5 rounded-lg bg-n-alpha-1 p-1"
            role="group"
            :aria-label="$t('INBOX_MGMT.WIDGET_PREVIEW.VIEW_LABEL')"
          >
            <button
              v-for="view in previewViews"
              :key="view.value"
              type="button"
              class="min-h-8 rounded-md px-1 text-xs font-medium leading-tight focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-blue-9"
              :class="
                selectedView === view.value
                  ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
                  : 'text-n-slate-11 hover:text-n-slate-12'
              "
              :aria-pressed="selectedView === view.value"
              @click="selectPreviewView(view.value)"
            >
              {{ view.label }}
            </button>
          </div>
          <div
            class="mx-auto h-[min(36rem,72svh)] min-h-96 max-w-[24rem] overflow-hidden rounded-xl border border-n-weak bg-n-solid-2 xl:h-[min(40rem,70svh)]"
          >
            <WidgetLivePreview
              ref="livePreview"
              bare
              :inbox-id="inbox.id"
              :config="previewConfig"
              @view-change="selectedView = $event"
            />
          </div>
        </div>
      </aside>

      <div
        class="flex min-w-0 flex-col gap-4"
        :class="
          hasPreview
            ? 'row-start-2 xl:col-start-1 xl:row-start-1'
            : 'row-start-1'
        "
      >
        <WidgetEssentials
          v-if="section === 'appearance'"
          v-model:form="form"
          inbox-icon="i-lucide-message-circle"
          :name-error="nameError"
          @upload-avatar="uploadAvatar"
          @delete-avatar="deleteAvatar"
        />

        <WidgetWelcome
          v-else-if="section === 'welcome'"
          v-model:form="form"
          :portals="portals"
        />

        <WidgetBehavior
          v-else-if="section === 'conversation'"
          v-model:form="form"
          :show-continuity-toggle="showContinuityToggle"
          :is-continuity-disabled="isContinuityDisabled"
          :continuity-description="continuityDescription"
        >
          <WidgetAiAgentCard
            v-if="hasCaptain && aiAgent"
            :assistant="aiAgent"
          />
          <SettingsToggleSection
            v-else
            v-model="form.greetingEnabled"
            inset
            :header="
              $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_TOGGLE.LABEL')
            "
            :description="
              $t(
                'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_TOGGLE.HELP_TEXT'
              )
            "
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
        </WidgetBehavior>

        <WidgetInstallation
          v-else-if="section === 'installation'"
          v-model:form="form"
          :inbox-id="inbox.id"
          :snippet="snippet"
          :saved-website-url="inbox.website_url || ''"
          :has-unsaved-snippet="hasUnsavedSnippet"
        />

        <WidgetSecurity
          v-else-if="section === 'security'"
          v-model:form="form"
          :inbox="inbox"
        >
          <slot name="danger" />
        </WidgetSecurity>

        <div v-show="!isWidgetSection" class="contents">
          <slot />
        </div>

        <p
          v-if="hasUnsavedSnippet && section !== 'installation'"
          class="m-0 rounded-xl border border-n-weak bg-n-solid-1 px-4 py-3 text-sm text-n-slate-11"
        >
          {{ $t('INBOX_MGMT.WEBSITE_SETTINGS.EMBED_CHANGED') }}
          <button
            type="button"
            class="text-n-blue-11 hover:underline"
            @click="$emit('openInstallation')"
          >
            {{ $t('INBOX_MGMT.WEBSITE_SETTINGS.PAGES.INSTALL.TITLE') }}
          </button>
        </p>
      </div>
    </div>

    <SettingsSaveBar
      :class="{ 'xl:me-[22.25rem]': hasPreview }"
      :is-dirty="isDirty"
      :hide-actions="!isWidgetSection"
      :is-saving="uiFlags.isUpdating"
      :save-label="$t('INBOX_MGMT.WEBSITE_SETTINGS.SAVE_WIDGET')"
      :unsaved-label="$t('INBOX_MGMT.WEBSITE_SETTINGS.UNSAVED_WIDGET')"
      @save="save"
      @discard="resetForm"
    />
  </div>
</template>

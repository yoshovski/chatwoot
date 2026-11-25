<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useConfig } from 'dashboard/composables/useConfig';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import GuidedSetupAPI from 'dashboard/api/captain/guidedSetup';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import WidgetSection from './WidgetSection.vue';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import InstallCheckResult from 'dashboard/routes/dashboard/home/setup/steps/InstallCheckResult.vue';

const props = defineProps({
  inboxId: { type: Number, required: true },
  snippet: { type: String, required: true },
  savedWebsiteUrl: { type: String, default: '' },
  // The snippet's launcher settings differ from the saved ones until the page is saved.
  hasUnsavedSnippet: { type: Boolean, default: false },
});

const form = defineModel('form', { type: Object, required: true });

const MOBILE_WEBVIEW_FLAG = 'allow_mobile_webview';

const { t } = useI18n();
// The installation check lives in the Enterprise guided setup.
const { isEnterprise } = useConfig();
const isChecking = ref(false);
const result = ref('');

const websiteUrlChanged = computed(
  () => form.value.websiteUrl !== props.savedWebsiteUrl
);

const site = computed(() => {
  try {
    return new URL(props.savedWebsiteUrl).host.replace(/^www\./, '');
  } catch {
    return props.savedWebsiteUrl;
  }
});

const allowMobileWebview = computed({
  get: () => form.value.selectedFeatureFlags.includes(MOBILE_WEBVIEW_FLAG),
  set: enabled => {
    const flags = form.value.selectedFeatureFlags.filter(
      flag => flag !== MOBILE_WEBVIEW_FLAG
    );
    form.value.selectedFeatureFlags = enabled
      ? [...flags, MOBILE_WEBVIEW_FLAG]
      : flags;
  },
});

const copy = async () => {
  await copyTextToClipboard(props.snippet);
  useAlert(t('INBOX_MGMT.WIDGET_SETTINGS.INSTALLATION.COPIED'));
};

const check = async () => {
  isChecking.value = true;
  try {
    const { data } = await GuidedSetupAPI.checkInstallation(props.inboxId);
    result.value = data.status;
  } catch {
    result.value = 'error';
  } finally {
    isChecking.value = false;
  }
};
</script>

<template>
  <WidgetSection :title="$t('INBOX_MGMT.WEBSITE_SETTINGS.SITE')">
    <div class="flex flex-col gap-3 sm:flex-row sm:items-end">
      <Input
        v-model="form.websiteUrl"
        class="min-w-0 flex-1"
        :label="$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_DOMAIN.LABEL')"
        :placeholder="
          $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_DOMAIN.PLACEHOLDER')
        "
      />
      <Button
        v-if="isEnterprise"
        class="min-h-10 self-start whitespace-nowrap sm:self-end"
        :label="$t('INBOX_MGMT.WIDGET_SETTINGS.INSTALLATION.CHECK')"
        icon="i-lucide-radar"
        size="sm"
        variant="faded"
        color="slate"
        :is-loading="isChecking"
        :disabled="websiteUrlChanged"
        @click="check"
      />
    </div>
    <div
      v-if="isEnterprise && (websiteUrlChanged || result)"
      class="flex flex-col gap-2"
    >
      <p v-if="websiteUrlChanged" class="m-0 text-sm text-n-slate-11">
        {{ $t('INBOX_MGMT.WEBSITE_SETTINGS.SAVE_SITE_FIRST') }}
      </p>
      <InstallCheckResult
        v-if="result && !isChecking && !websiteUrlChanged"
        :result="result"
        :site="site"
      />
    </div>
  </WidgetSection>
  <WidgetSection
    :title="$t('INBOX_MGMT.WIDGET_SETTINGS.INSTALLATION.SCRIPT')"
    :description="$t('INBOX_MGMT.WIDGET_SETTINGS.INSTALLATION.DESCRIPTION')"
  >
    <div class="flex flex-col gap-2">
      <div class="flex min-w-0 flex-col gap-2">
        <pre
          class="mb-0 max-h-56 overflow-auto rounded-lg bg-n-alpha-1 p-4 text-xs leading-relaxed text-n-slate-12"
        ><code>{{ snippet }}</code></pre>
        <Button
          class="self-end"
          :label="$t('INBOX_MGMT.WIDGET_SETTINGS.INSTALLATION.COPY')"
          icon="i-lucide-copy"
          size="sm"
          variant="faded"
          color="slate"
          :disabled="hasUnsavedSnippet"
          @click="copy"
        />
      </div>
      <p v-if="hasUnsavedSnippet" class="mb-0 text-label-small text-n-amber-11">
        {{ $t('INBOX_MGMT.WIDGET_SETTINGS.INSTALLATION.SNIPPET_CHANGED') }}
      </p>
    </div>
  </WidgetSection>
  <WidgetSection :title="$t('INBOX_MGMT.WEBSITE_SETTINGS.EMBED_OPTIONS')">
    <SettingsToggleSection
      v-model="allowMobileWebview"
      inset
      :header="$t('INBOX_MGMT.SETTINGS_POPUP.ALLOW_MOBILE_WEBVIEW.LABEL')"
      :description="
        $t('INBOX_MGMT.SETTINGS_POPUP.ALLOW_MOBILE_WEBVIEW.SUBTITLE')
      "
    />
  </WidgetSection>
</template>

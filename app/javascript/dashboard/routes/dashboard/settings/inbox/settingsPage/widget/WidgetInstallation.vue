<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useConfig } from 'dashboard/composables/useConfig';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import GuidedSetupAPI from 'dashboard/api/captain/guidedSetup';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import InstallCheckResult from 'dashboard/routes/dashboard/home/setup/steps/InstallCheckResult.vue';
import WidgetSection from './WidgetSection.vue';

const props = defineProps({
  inboxId: { type: Number, required: true },
  snippet: { type: String, required: true },
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

const site = computed(() => {
  try {
    return new URL(form.value.websiteUrl).host.replace(/^www\./, '');
  } catch {
    return form.value.websiteUrl;
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
  <WidgetSection
    :title="$t('INBOX_MGMT.WIDGET_SETTINGS.INSTALLATION.TITLE')"
    :description="$t('INBOX_MGMT.WIDGET_SETTINGS.INSTALLATION.DESCRIPTION')"
  >
    <div class="relative min-w-0">
      <pre
        class="mb-0 max-h-56 overflow-auto rounded-lg bg-n-alpha-1 p-4 pe-24 text-xs leading-relaxed text-n-slate-12"
      ><code>{{ snippet }}</code></pre>
      <Button
        class="absolute end-2 top-2"
        :label="$t('INBOX_MGMT.WIDGET_SETTINGS.INSTALLATION.COPY')"
        icon="i-lucide-copy"
        size="xs"
        variant="faded"
        color="slate"
        @click="copy"
      />
    </div>
    <p v-if="hasUnsavedSnippet" class="mb-0 text-label-small text-n-amber-11">
      {{ $t('INBOX_MGMT.WIDGET_SETTINGS.INSTALLATION.SNIPPET_CHANGED') }}
    </p>

    <Input
      v-model="form.websiteUrl"
      :label="$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_DOMAIN.LABEL')"
      :placeholder="
        $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_DOMAIN.PLACEHOLDER')
      "
    />

    <div v-if="isEnterprise" class="flex flex-col gap-2">
      <Button
        class="self-start"
        :label="$t('INBOX_MGMT.WIDGET_SETTINGS.INSTALLATION.CHECK')"
        icon="i-lucide-radar"
        size="sm"
        variant="faded"
        color="slate"
        :is-loading="isChecking"
        @click="check"
      />
      <InstallCheckResult
        v-if="result && !isChecking"
        :result="result"
        :site="site"
      />
    </div>

    <SettingsToggleSection
      :header="$t('INBOX_MGMT.SETTINGS_POPUP.ALLOWED_DOMAINS.TITLE')"
      :description="$t('INBOX_MGMT.SETTINGS_POPUP.ALLOWED_DOMAINS.DESCRIPTION')"
      hide-toggle
    >
      <template #editor>
        <TextArea
          v-model="form.allowedDomains"
          :placeholder="
            $t('INBOX_MGMT.SETTINGS_POPUP.ALLOWED_DOMAINS.PLACEHOLDER')
          "
          auto-height
          resize
          class="w-full [&>div]:!bg-transparent [&>div]:!border-none [&>div]:!border-0 [&>div]:px-0 [&>div]:pb-0 [&>div]:pt-0"
        />
      </template>
    </SettingsToggleSection>
    <SettingsToggleSection
      v-model="allowMobileWebview"
      :header="$t('INBOX_MGMT.SETTINGS_POPUP.ALLOW_MOBILE_WEBVIEW.LABEL')"
      :description="
        $t('INBOX_MGMT.SETTINGS_POPUP.ALLOW_MOBILE_WEBVIEW.SUBTITLE')
      "
    />
  </WidgetSection>
</template>

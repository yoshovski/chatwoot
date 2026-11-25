<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import HmacSecretKey from '../components/HmacSecretKey.vue';
import WidgetSection from './WidgetSection.vue';

const props = defineProps({ inbox: { type: Object, required: true } });
const form = defineModel('form', { type: Object, required: true });

const DEMO_SLUG_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const IDENTITY_VALIDATION_DOCS_URL =
  'https://www.chatwoot.com/docs/product/channels/live-chat/sdk/identity-validation/';

const { t } = useI18n();

const demoUrl = computed(() => {
  const id = form.value.demoSlug.trim() || props.inbox.website_token;
  return `${window.location.origin}/demo/${id}`;
});

const isDemoSlugInvalid = computed(() => {
  const slug = form.value.demoSlug.trim();
  return !!slug && !DEMO_SLUG_PATTERN.test(slug);
});

const demoModeDescription = computed(() => {
  const description = t('INBOX_MGMT.SETTINGS_POPUP.ENABLE_DEMO_MODE_SUB_TEXT');
  return form.value.demoModeEnabled
    ? `${description} ${demoUrl.value}`
    : description;
});
</script>

<template>
  <WidgetSection :title="$t('INBOX_MGMT.WEBSITE_SETTINGS.ACCESS')">
    <SettingsToggleSection
      inset
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
  </WidgetSection>
  <WidgetSection :title="$t('INBOX_MGMT.WEBSITE_SETTINGS.IDENTITY')">
    <details>
      <summary
        class="cursor-pointer rounded-md text-sm font-medium text-n-blue-11"
      >
        {{ $t('INBOX_MGMT.WEBSITE_SETTINGS.DEVELOPER_KEYS') }}
      </summary>
      <div class="mt-4">
        <SettingsToggleSection
          inset
          :header="$t('INBOX_MGMT.SETTINGS_POPUP.IDENTITY_VALIDATION.TITLE')"
          :description="
            $t('INBOX_MGMT.SETTINGS_POPUP.IDENTITY_VALIDATION.DESCRIPTION')
          "
          hide-toggle
        >
          <template #editor>
            <p class="mb-1 text-sm font-medium text-n-slate-12">
              {{
                $t('INBOX_MGMT.SETTINGS_POPUP.IDENTITY_VALIDATION.SECRET_KEY')
              }}
            </p>
            <HmacSecretKey :inbox="inbox" />
            <p class="mt-1.5 mb-0 text-label-small text-n-slate-11">
              {{ $t('INBOX_MGMT.SETTINGS_POPUP.HMAC_DESCRIPTION') }}
              <a
                target="_blank"
                rel="noopener noreferrer"
                :href="IDENTITY_VALIDATION_DOCS_URL"
                class="text-n-blue-11 hover:underline"
              >
                {{
                  $t('INBOX_MGMT.SETTINGS_POPUP.IDENTITY_VALIDATION.VIEW_DOCS')
                }}
              </a>
            </p>
          </template>
        </SettingsToggleSection>
      </div>
    </details>
    <SettingsToggleSection
      v-model="form.hmacMandatory"
      inset
      :header="
        $t('INBOX_MGMT.SETTINGS_POPUP.IDENTITY_VALIDATION.REQUIRE_LABEL')
      "
      :description="
        $t('INBOX_MGMT.SETTINGS_POPUP.IDENTITY_VALIDATION.REQUIRE_DESCRIPTION')
      "
    />
  </WidgetSection>

  <WidgetSection :title="$t('INBOX_MGMT.WEBSITE_SETTINGS.TESTING')">
    <SettingsToggleSection
      v-model="form.demoModeEnabled"
      inset
      :header="$t('INBOX_MGMT.SETTINGS_POPUP.ENABLE_DEMO_MODE')"
      :description="demoModeDescription"
    />
    <SettingsFieldSection
      v-if="form.demoModeEnabled"
      stacked
      :label="$t('INBOX_MGMT.SETTINGS_POPUP.DEMO_SLUG')"
      :help-text="$t('INBOX_MGMT.SETTINGS_POPUP.DEMO_SLUG_HINT')"
    >
      <Input
        v-model="form.demoSlug"
        :placeholder="$t('INBOX_MGMT.SETTINGS_POPUP.DEMO_SLUG_PLACEHOLDER')"
        :message="
          isDemoSlugInvalid
            ? $t('INBOX_MGMT.SETTINGS_POPUP.DEMO_SLUG_ERROR')
            : ''
        "
        :message-type="isDemoSlugInvalid ? 'error' : 'info'"
      />
    </SettingsFieldSection>

    <SettingsFieldSection
      stacked
      :label="$t('INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.WIDGET_HEIGHT')"
      :help-text="
        $t('INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.WIDGET_HEIGHT_HELP')
      "
    >
      <Input
        v-model.number="form.widgetHeight"
        type="number"
        min="320"
        max="900"
        class="max-w-40"
      />
    </SettingsFieldSection>
  </WidgetSection>
  <WidgetSection :title="$t('INBOX_MGMT.WEBSITE_SETTINGS.DELETE_TITLE')">
    <p class="m-0 text-sm text-n-slate-11">
      {{ $t('INBOX_MGMT.WEBSITE_SETTINGS.DELETE_DESCRIPTION') }}
    </p>
    <slot />
  </WidgetSection>
</template>

<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import ColorPicker from 'dashboard/components-next/colorpicker/ColorPicker.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import OrderedTextList from 'dashboard/components-next/ordered-text-list/OrderedTextList.vue';
import SelectInput from 'dashboard/components-next/select/Select.vue';
import SettingsAccordion from 'dashboard/components-next/Settings/SettingsAccordion.vue';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import SenderNameExamplePreview from '../../components/SenderNameExamplePreview.vue';
import HmacSecretKey from '../components/HmacSecretKey.vue';

const props = defineProps({
  inbox: { type: Object, required: true },
  portals: { type: Array, default: () => [] },
  showContinuityToggle: { type: Boolean, default: false },
  isContinuityDisabled: { type: Boolean, default: false },
  continuityDescription: { type: String, default: '' },
});

defineEmits(['openPreChatForm']);

const form = defineModel('form', { type: Object, required: true });

const DEMO_SLUG_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const IDENTITY_VALIDATION_DOCS_URL =
  'https://www.chatwoot.com/docs/product/channels/live-chat/sdk/identity-validation/';

const { t } = useI18n();

const replyTimeOptions = computed(() => [
  {
    value: 'immediately',
    label: t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.IMMEDIATELY'),
  },
  {
    value: 'in_a_few_minutes',
    label: t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.IN_A_FEW_MINUTES'),
  },
  {
    value: 'in_a_few_hours',
    label: t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.IN_A_FEW_HOURS'),
  },
  {
    value: 'in_a_day',
    label: t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.IN_A_DAY'),
  },
]);

const conversationStarterActions = computed(() => [
  {
    value: 'message',
    label: t(
      'INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.CONVERSATION_STARTERS.ACTIONS.MESSAGE'
    ),
  },
  {
    value: 'url',
    label: t(
      'INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.CONVERSATION_STARTERS.ACTIONS.URL'
    ),
  },
  {
    value: 'canned',
    label: t(
      'INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.CONVERSATION_STARTERS.ACTIONS.CANNED'
    ),
  },
]);

const composerFeatures = computed(() => [
  {
    flag: 'attachments',
    label: t('INBOX_MGMT.FEATURES.DISPLAY_FILE_PICKER'),
  },
  {
    flag: 'emoji_picker',
    label: t('INBOX_MGMT.FEATURES.DISPLAY_EMOJI_PICKER'),
  },
  {
    flag: 'end_conversation',
    label: t('INBOX_MGMT.FEATURES.ALLOW_END_CONVERSATION'),
  },
  {
    flag: 'use_inbox_avatar_for_bot',
    label: t('INBOX_MGMT.FEATURES.USE_INBOX_AVATAR_FOR_BOT'),
  },
]);

const portalOptions = computed(() => [
  { value: '', label: t('INBOX_MGMT.HELP_CENTER.NONE') },
  ...props.portals.map(portal => ({ value: portal.slug, label: portal.name })),
]);

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

const hasFeature = flag => form.value.selectedFeatureFlags.includes(flag);

const setFeature = (flag, enabled) => {
  const flags = form.value.selectedFeatureFlags.filter(item => item !== flag);
  form.value.selectedFeatureFlags = enabled ? [...flags, flag] : flags;
};
</script>

<template>
  <section
    class="rounded-xl bg-n-solid-1 px-5 outline outline-1 -outline-offset-1 outline-n-weak [&>button:first-child]:border-t-0"
  >
    <SettingsAccordion
      :title="$t('INBOX_MGMT.WIDGET_SETTINGS.ADVANCED.TITLE')"
      :default-open="false"
    >
      <SettingsToggleSection
        v-model="form.showHome"
        :header="$t('INBOX_MGMT.WIDGET_SETTINGS.ADVANCED.HOME_SCREEN.TITLE')"
        :description="
          $t('INBOX_MGMT.WIDGET_SETTINGS.ADVANCED.HOME_SCREEN.DESCRIPTION')
        "
      >
        <template v-if="form.showHome" #editor>
          <p class="mb-2 text-heading-3 text-n-slate-12">
            {{
              $t(
                'INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.CONVERSATION_STARTERS.LABEL'
              )
            }}
          </p>
          <OrderedTextList
            v-model="form.conversationStarters"
            allow-actions
            :action-options="conversationStarterActions"
            :add-label="
              $t(
                'INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.CONVERSATION_STARTERS.ADD'
              )
            "
            :empty-label="
              $t(
                'INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.CONVERSATION_STARTERS.EMPTY'
              )
            "
            :placeholder="
              $t(
                'INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.CONVERSATION_STARTERS.PLACEHOLDER'
              )
            "
            :url-placeholder="
              $t(
                'INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.CONVERSATION_STARTERS.URL_PLACEHOLDER'
              )
            "
            :canned-placeholder="
              $t(
                'INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.CONVERSATION_STARTERS.CANNED_PLACEHOLDER'
              )
            "
            :reorder-label="
              $t('INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.REORDER')
            "
            :delete-label="
              $t('INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.DELETE')
            "
          />
          <p class="mt-2 mb-0 text-label-small text-n-slate-11">
            {{
              $t(
                'INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.CONVERSATION_STARTERS.HELP'
              )
            }}
          </p>
        </template>
      </SettingsToggleSection>

      <SettingsFieldSection
        :label="$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.TITLE')"
        :help-text="$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.HELP_TEXT')"
      >
        <div class="flex flex-col gap-3">
          <SelectInput v-model="form.replyTime" :options="replyTimeOptions" />
          <Input
            v-model="form.replyTimeMessage"
            :label="
              $t(
                'INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.CUSTOM_MESSAGE_LABEL'
              )
            "
            :placeholder="
              $t(
                'INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.CUSTOM_MESSAGE_PLACEHOLDER'
              )
            "
            :message="
              $t(
                'INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.CUSTOM_MESSAGE_HELP_TEXT'
              )
            "
            maxlength="120"
          />
        </div>
      </SettingsFieldSection>

      <SettingsToggleSection
        v-model="form.emailCollectEnabled"
        :header="$t('INBOX_MGMT.SETTINGS_POPUP.ENABLE_EMAIL_COLLECT_BOX')"
        :description="
          $t('INBOX_MGMT.SETTINGS_POPUP.ENABLE_EMAIL_COLLECT_BOX_SUB_TEXT')
        "
      />
      <SettingsToggleSection
        v-if="showContinuityToggle"
        v-model="form.continuityViaEmail"
        :header="$t('INBOX_MGMT.SETTINGS_POPUP.ENABLE_CONTINUITY_VIA_EMAIL')"
        :description="continuityDescription"
        :hide-toggle="isContinuityDisabled"
        :class="{ 'cursor-not-allowed opacity-50': isContinuityDisabled }"
      />

      <SettingsToggleSection
        :header="$t('INBOX_MGMT.WIDGET_SETTINGS.ADVANCED.PRE_CHAT.TITLE')"
        :description="
          $t('INBOX_MGMT.WIDGET_SETTINGS.ADVANCED.PRE_CHAT.DESCRIPTION')
        "
        hide-toggle
      >
        <template #hiddenToggle>
          <Button
            :label="$t('INBOX_MGMT.WIDGET_SETTINGS.ADVANCED.PRE_CHAT.LINK')"
            size="sm"
            variant="link"
            @click="$emit('openPreChatForm')"
          />
        </template>
      </SettingsToggleSection>

      <SettingsToggleSection
        v-model="form.allowMessagesAfterResolved"
        :header="$t('INBOX_MGMT.SETTINGS_POPUP.ALLOW_MESSAGES_AFTER_RESOLVED')"
        :description="
          $t('INBOX_MGMT.SETTINGS_POPUP.ALLOW_MESSAGES_AFTER_RESOLVED_SUB_TEXT')
        "
      />

      <SettingsFieldSection
        :label="$t('INBOX_MGMT.FEATURES.LABEL')"
        class="[&>div]:!items-start"
      >
        <div class="flex flex-col gap-2">
          <label
            v-for="feature in composerFeatures"
            :key="feature.flag"
            class="flex items-center gap-2 text-body-main text-n-slate-12"
          >
            <Checkbox
              :model-value="hasFeature(feature.flag)"
              @update:model-value="setFeature(feature.flag, $event)"
            />
            {{ feature.label }}
          </label>
        </div>
      </SettingsFieldSection>

      <SettingsFieldSection
        :label="
          $t('INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.WIDGET_TEXT_COLOR')
        "
      >
        <ColorPicker
          v-model="form.widgetTextColor"
          @update:model-value="form.isWidgetTextColorCustom = true"
        />
      </SettingsFieldSection>
      <SettingsFieldSection
        :label="
          $t('INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.WIDGET_ICON_COLOR')
        "
      >
        <ColorPicker
          v-model="form.widgetIconColor"
          @update:model-value="form.isWidgetIconColorCustom = true"
        />
      </SettingsFieldSection>
      <SettingsFieldSection
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

      <SettingsFieldSection
        :label="$t('INBOX_MGMT.HELP_CENTER.LABEL')"
        :help-text="$t('INBOX_MGMT.HELP_CENTER.SUB_TEXT')"
      >
        <SelectInput
          v-model="form.portalSlug"
          :placeholder="$t('INBOX_MGMT.HELP_CENTER.PLACEHOLDER')"
          :options="portalOptions"
        />
      </SettingsFieldSection>

      <SettingsFieldSection
        :label="$t('INBOX_MGMT.EDIT.SENDER_NAME_SECTION.TITLE')"
        class="[&>div]:!items-start"
      >
        <Input
          v-model="form.businessName"
          :placeholder="
            $t('INBOX_MGMT.EDIT.SENDER_NAME_SECTION.BUSINESS_NAME.PLACEHOLDER')
          "
        />
        <template #extra>
          <SenderNameExamplePreview
            :sender-name-type="form.senderNameType"
            :business-name="form.businessName"
            is-website-channel
            @update="form.senderNameType = $event"
          />
        </template>
      </SettingsFieldSection>

      <SettingsToggleSection
        v-model="form.demoModeEnabled"
        :header="$t('INBOX_MGMT.SETTINGS_POPUP.ENABLE_DEMO_MODE')"
        :description="demoModeDescription"
      />
      <SettingsFieldSection
        v-if="form.demoModeEnabled"
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

      <SettingsToggleSection
        :header="$t('INBOX_MGMT.SETTINGS_POPUP.IDENTITY_VALIDATION.TITLE')"
        :description="
          $t('INBOX_MGMT.SETTINGS_POPUP.IDENTITY_VALIDATION.DESCRIPTION')
        "
        hide-toggle
      >
        <template #editor>
          <p class="mb-1 text-sm font-medium text-n-slate-12">
            {{ $t('INBOX_MGMT.SETTINGS_POPUP.IDENTITY_VALIDATION.SECRET_KEY') }}
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
      <SettingsToggleSection
        v-model="form.hmacMandatory"
        :header="
          $t('INBOX_MGMT.SETTINGS_POPUP.IDENTITY_VALIDATION.REQUIRE_LABEL')
        "
        :description="
          $t(
            'INBOX_MGMT.SETTINGS_POPUP.IDENTITY_VALIDATION.REQUIRE_DESCRIPTION'
          )
        "
      />
    </SettingsAccordion>
  </section>
</template>

<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import SelectInput from 'dashboard/components-next/select/Select.vue';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import SenderNameExamplePreview from '../../components/SenderNameExamplePreview.vue';
import WidgetSection from './WidgetSection.vue';

defineProps({
  showContinuityToggle: { type: Boolean, default: false },
  isContinuityDisabled: { type: Boolean, default: false },
  continuityDescription: { type: String, default: '' },
});
const form = defineModel('form', { type: Object, required: true });
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

const hasFeature = flag => form.value.selectedFeatureFlags.includes(flag);

const setFeature = (flag, enabled) => {
  const flags = form.value.selectedFeatureFlags.filter(item => item !== flag);
  form.value.selectedFeatureFlags = enabled ? [...flags, flag] : flags;
};
</script>

<template>
  <WidgetSection
    :title="$t('INBOX_MGMT.WEBSITE_SETTINGS.REPLIES')"
    :help="$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.HELP_TEXT')"
  >
    <slot />
    <div class="grid gap-4 border-t border-n-weak pt-4 sm:grid-cols-2">
      <SettingsFieldSection
        stacked
        :label="$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.TITLE')"
      >
        <SelectInput
          v-model="form.replyTime"
          stretch
          :options="replyTimeOptions"
          :aria-label="$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.TITLE')"
        />
      </SettingsFieldSection>
      <Input
        v-model="form.replyTimeMessage"
        :label="
          $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.CUSTOM_MESSAGE_LABEL')
        "
        :placeholder="
          $t(
            'INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.CUSTOM_MESSAGE_PLACEHOLDER'
          )
        "
        maxlength="120"
      />
    </div>
  </WidgetSection>

  <WidgetSection :title="$t('INBOX_MGMT.WEBSITE_SETTINGS.CHAT_OPTIONS')">
    <div
      class="flex flex-col divide-y divide-n-weak [&>div]:py-3 [&>div:first-child]:pt-0 [&>div:last-child]:pb-0"
    >
      <SettingsToggleSection
        v-model="form.allowMessagesAfterResolved"
        inset
        :header="$t('INBOX_MGMT.SETTINGS_POPUP.ALLOW_MESSAGES_AFTER_RESOLVED')"
        :description="
          $t('INBOX_MGMT.SETTINGS_POPUP.ALLOW_MESSAGES_AFTER_RESOLVED_SUB_TEXT')
        "
      />

      <SettingsToggleSection
        v-model="form.emailCollectEnabled"
        inset
        :header="$t('INBOX_MGMT.SETTINGS_POPUP.ENABLE_EMAIL_COLLECT_BOX')"
        :description="
          $t('INBOX_MGMT.SETTINGS_POPUP.ENABLE_EMAIL_COLLECT_BOX_SUB_TEXT')
        "
      />
      <SettingsToggleSection
        v-if="showContinuityToggle"
        v-model="form.continuityViaEmail"
        inset
        :header="$t('INBOX_MGMT.SETTINGS_POPUP.ENABLE_CONTINUITY_VIA_EMAIL')"
        :description="continuityDescription"
        :hide-toggle="isContinuityDisabled"
        :class="{ 'cursor-not-allowed opacity-50': isContinuityDisabled }"
      />
    </div>
    <SettingsFieldSection
      stacked
      :label="$t('INBOX_MGMT.FEATURES.LABEL')"
      class="[&>div]:!items-start"
    >
      <div class="grid gap-3 border-t border-n-weak pt-3 sm:grid-cols-2">
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
  </WidgetSection>

  <WidgetSection :title="$t('INBOX_MGMT.WEBSITE_SETTINGS.SENDER')">
    <Input
      v-model="form.businessName"
      :label="$t('INBOX_MGMT.WEBSITE_SETTINGS.BUSINESS_NAME')"
      :placeholder="
        $t('INBOX_MGMT.EDIT.SENDER_NAME_SECTION.BUSINESS_NAME.PLACEHOLDER')
      "
    />
    <SenderNameExamplePreview
      :sender-name-type="form.senderNameType"
      :business-name="form.businessName"
      is-website-channel
      @update="form.senderNameType = $event"
    />
  </WidgetSection>
</template>

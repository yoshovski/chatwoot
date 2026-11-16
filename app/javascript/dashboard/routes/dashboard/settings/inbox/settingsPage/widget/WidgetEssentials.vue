<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'next/avatar/Avatar.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Editor from 'dashboard/components-next/Editor/Editor.vue';
import ColorPicker from 'dashboard/components-next/colorpicker/ColorPicker.vue';
import SelectInput from 'dashboard/components-next/select/Select.vue';
import WidgetSection from './WidgetSection.vue';

defineProps({
  inboxIcon: { type: String, default: '' },
  nameError: { type: String, default: '' },
});

defineEmits(['uploadAvatar', 'deleteAvatar']);

const form = defineModel('form', { type: Object, required: true });

const { t } = useI18n();

const positionOptions = computed(() => [
  {
    value: 'right',
    label: t(
      'INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.WIDGET_BUBBLE_POSITION.RIGHT'
    ),
  },
  {
    value: 'left',
    label: t(
      'INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.WIDGET_BUBBLE_POSITION.LEFT'
    ),
  },
]);

const bubbleTypeOptions = computed(() => [
  {
    value: 'standard',
    label: t('INBOX_MGMT.WIDGET_SETTINGS.ESSENTIALS.LAUNCHER_STYLE.STANDARD'),
  },
  {
    value: 'expanded_bubble',
    label: t('INBOX_MGMT.WIDGET_SETTINGS.ESSENTIALS.LAUNCHER_STYLE.EXPANDED'),
  },
]);
</script>

<template>
  <WidgetSection
    :title="$t('INBOX_MGMT.WIDGET_SETTINGS.ESSENTIALS.TITLE')"
    :description="$t('INBOX_MGMT.WIDGET_SETTINGS.ESSENTIALS.DESCRIPTION')"
  >
    <div class="flex items-center gap-4">
      <Avatar
        :src="form.avatarUrl"
        :size="56"
        :icon-name="inboxIcon"
        name=""
        allow-upload
        rounded-full
        @upload="$emit('uploadAvatar', $event)"
        @delete="$emit('deleteAvatar')"
      />
      <Input
        v-model="form.name"
        class="flex-1 min-w-0"
        :label="$t('INBOX_MGMT.ADD.WEBSITE_NAME.LABEL')"
        :placeholder="$t('INBOX_MGMT.ADD.WEBSITE_NAME.PLACEHOLDER')"
        :message="nameError"
        :message-type="nameError ? 'error' : 'info'"
      />
    </div>

    <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
      <div class="flex flex-col gap-1.5">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.WIDGET_COLOR.LABEL') }}
        </label>
        <ColorPicker v-model="form.widgetColor" />
      </div>
      <div class="flex flex-col gap-1.5">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.WIDGET_TEXT_COLOR') }}
        </label>
        <ColorPicker
          v-model="form.widgetTextColor"
          @update:model-value="form.isWidgetTextColorCustom = true"
        />
      </div>
      <div class="flex flex-col gap-1.5">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.WIDGET_ICON_COLOR') }}
        </label>
        <ColorPicker
          v-model="form.widgetIconColor"
          @update:model-value="form.isWidgetIconColorCustom = true"
        />
      </div>
    </div>

    <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
      <div class="flex flex-col gap-1.5">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.WIDGET_SETTINGS.ESSENTIALS.POSITION') }}
        </label>
        <SelectInput v-model="form.position" :options="positionOptions" />
      </div>
      <div class="flex flex-col gap-1.5">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.WIDGET_SETTINGS.ESSENTIALS.LAUNCHER_STYLE.LABEL') }}
        </label>
        <SelectInput v-model="form.bubbleType" :options="bubbleTypeOptions" />
      </div>
    </div>

    <Input
      v-if="form.bubbleType === 'expanded_bubble'"
      v-model="form.launcherTitle"
      :label="$t('INBOX_MGMT.WIDGET_SETTINGS.ESSENTIALS.LAUNCHER_TEXT')"
      :placeholder="
        $t(
          'INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.WIDGET_BUBBLE_LAUNCHER_TITLE.PLACE_HOLDER'
        )
      "
    />

    <div class="flex flex-col gap-4 border-t border-n-weak pt-4">
      <Input
        v-model="form.welcomeTitle"
        :label="
          $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TITLE.LABEL')
        "
        :placeholder="
          $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TITLE.PLACEHOLDER')
        "
      />
      <div class="flex flex-col gap-1.5">
        <label class="text-sm font-medium text-n-slate-12">
          {{
            $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TAGLINE.LABEL')
          }}
        </label>
        <Editor
          v-model="form.welcomeTagline"
          :placeholder="
            $t(
              'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TAGLINE.PLACEHOLDER'
            )
          "
          :max-length="255"
          channel-type="Context::InboxSettings"
        />
      </div>
    </div>
  </WidgetSection>
</template>

<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'next/avatar/Avatar.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import SelectInput from 'dashboard/components-next/select/Select.vue';
import WidgetSection from './WidgetSection.vue';
import WidgetColors from './WidgetColors.vue';

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
  <WidgetSection :title="$t('INBOX_MGMT.WEBSITE_SETTINGS.BRAND')">
    <div class="flex items-end gap-3 pb-3 border-b border-n-weak">
      <Avatar
        :src="form.avatarUrl"
        :size="40"
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

    <WidgetColors v-model:form="form" />
  </WidgetSection>
  <WidgetSection
    :title="$t('INBOX_MGMT.WEBSITE_SETTINGS.LAUNCHER')"
    :help="$t('INBOX_MGMT.WEBSITE_SETTINGS.LAUNCHER_HELP')"
  >
    <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
      <div class="flex min-w-0 flex-col gap-1.5">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.WIDGET_SETTINGS.ESSENTIALS.POSITION') }}
        </label>
        <SelectInput
          v-model="form.position"
          stretch
          :options="positionOptions"
          :aria-label="$t('INBOX_MGMT.WIDGET_SETTINGS.ESSENTIALS.POSITION')"
        />
      </div>
      <div class="flex min-w-0 flex-col gap-1.5">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.WIDGET_SETTINGS.ESSENTIALS.LAUNCHER_STYLE.LABEL') }}
        </label>
        <SelectInput
          v-model="form.bubbleType"
          stretch
          :options="bubbleTypeOptions"
          :aria-label="
            $t('INBOX_MGMT.WIDGET_SETTINGS.ESSENTIALS.LAUNCHER_STYLE.LABEL')
          "
        />
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
  </WidgetSection>
</template>

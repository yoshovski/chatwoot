<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Editor from 'dashboard/components-next/Editor/Editor.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import OrderedTextList from 'dashboard/components-next/ordered-text-list/OrderedTextList.vue';
import SelectInput from 'dashboard/components-next/select/Select.vue';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import WidgetSection from './WidgetSection.vue';

const props = defineProps({ portals: { type: Array, default: () => [] } });
const form = defineModel('form', { type: Object, required: true });
const { t } = useI18n();

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

const portalOptions = computed(() => [
  { value: '', label: t('INBOX_MGMT.HELP_CENTER.NONE') },
  ...props.portals.map(portal => ({ value: portal.slug, label: portal.name })),
]);
</script>

<template>
  <WidgetSection>
    <SettingsToggleSection
      v-model="form.showHome"
      inset
      :header="$t('INBOX_MGMT.WIDGET_SETTINGS.ADVANCED.HOME_SCREEN.TITLE')"
      :description="
        $t('INBOX_MGMT.WIDGET_SETTINGS.ADVANCED.HOME_SCREEN.DESCRIPTION')
      "
    >
      <template v-if="form.showHome" #editor>
        <div class="flex min-w-0 flex-col gap-4">
          <Input
            v-model="form.welcomeTitle"
            :label="
              $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TITLE.LABEL')
            "
            :placeholder="
              $t(
                'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TITLE.PLACEHOLDER'
              )
            "
          />
          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-medium text-n-slate-12">
              {{
                $t(
                  'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TAGLINE.LABEL'
                )
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
              class="[&_.ProseMirror-woot-style]:!min-h-10"
            />
          </div>
          <SettingsFieldSection
            stacked
            :label="$t('INBOX_MGMT.HELP_CENTER.LABEL')"
            :help-text="$t('INBOX_MGMT.HELP_CENTER.SUB_TEXT')"
          >
            <SelectInput
              v-model="form.portalSlug"
              stretch
              :aria-label="$t('INBOX_MGMT.HELP_CENTER.LABEL')"
              :placeholder="$t('INBOX_MGMT.HELP_CENTER.PLACEHOLDER')"
              :options="portalOptions"
            />
          </SettingsFieldSection>
        </div>
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
          :delete-label="$t('INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.DELETE')"
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
  </WidgetSection>
</template>

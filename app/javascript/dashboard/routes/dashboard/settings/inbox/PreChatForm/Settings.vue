<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import PreChatFields from './PreChatFields.vue';
import { getPreChatFields } from 'dashboard/helper/preChat';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import WidgetSection from '../settingsPage/widget/WidgetSection.vue';
import ChannelFormActions from '../components/ChannelFormActions.vue';

const props = defineProps({
  inbox: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();
const store = useStore();

const uiFlags = useMapGetter('inboxes/getUIFlags');
const customAttributes = useMapGetter('attributes/getAttributes');

const preChatFormEnabled = ref(false);
const preChatMessage = ref('');
const preChatFields = ref([]);

const savedForm = computed(() => {
  const {
    id,
    pre_chat_form_enabled: enabled,
    pre_chat_form_options: options,
  } = props.inbox;
  return JSON.stringify({ id, enabled, options });
});

const getFields = () => {
  const { pre_chat_form_options: options } = props.inbox;
  const parsed = getPreChatFields({
    preChatFormOptions: { pre_chat_fields: [], ...options },
    customAttributes: customAttributes.value || [],
  });
  const storedFields = options?.pre_chat_fields || [];
  return parsed.pre_chat_fields.map(field => {
    const stored = storedFields.find(({ name }) => name === field.name);
    return {
      ...field,
      label: stored?.label || field.label,
      placeholder: stored?.placeholder ?? field.placeholder,
    };
  });
};

watch(
  savedForm,
  () => {
    preChatFormEnabled.value = !!props.inbox.pre_chat_form_enabled;
    preChatMessage.value =
      props.inbox.pre_chat_form_options?.pre_chat_message || '';
    preChatFields.value = getFields();
  },
  { immediate: true }
);

watch(customAttributes, () => {
  const existing = new Set(preChatFields.value.map(({ name }) => name));
  const additional = getFields().filter(({ name }) => !existing.has(name));
  preChatFields.value = [...preChatFields.value, ...additional];
});

const updateInbox = async () => {
  try {
    const payload = {
      id: props.inbox.id,
      formData: false,
      channel: {
        pre_chat_form_enabled: preChatFormEnabled.value,
        pre_chat_form_options: {
          pre_chat_message: preChatMessage.value,
          pre_chat_fields: preChatFields.value,
        },
      },
    };
    await store.dispatch('inboxes/updateInbox', payload);
    useAlert(t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
  }
};
</script>

<template>
  <form class="flex min-w-0 flex-col gap-4" @submit.prevent="updateInbox">
    <WidgetSection>
      <SettingsToggleSection
        v-model="preChatFormEnabled"
        inset
        :header="$t('INBOX_MGMT.PRE_CHAT_FORM.ENABLE.LABEL')"
        :description="$t('INBOX_MGMT.WEBSITE_SETTINGS.PRE_CHAT_REQUIRED')"
      >
        <template v-if="preChatFormEnabled" #editor>
          <p class="m-0 mb-2 text-sm font-medium text-n-slate-12">
            {{ $t('INBOX_MGMT.WEBSITE_SETTINGS.PRE_CHAT_INTRO') }}
          </p>
          <WootMessageEditor
            v-model="preChatMessage"
            :placeholder="
              $t('INBOX_MGMT.PRE_CHAT_FORM.PRE_CHAT_MESSAGE.PLACEHOLDER')
            "
          />
        </template>
      </SettingsToggleSection>
    </WidgetSection>

    <WidgetSection
      v-if="preChatFormEnabled"
      :title="$t('INBOX_MGMT.WEBSITE_SETTINGS.FORM_FIELDS')"
      :help="$t('INBOX_MGMT.WEBSITE_SETTINGS.FORM_ORDER_HELP')"
    >
      <PreChatFields v-model="preChatFields" />
    </WidgetSection>

    <ChannelFormActions>
      <Button
        type="submit"
        size="sm"
        :label="$t('INBOX_MGMT.SETTINGS_POPUP.UPDATE_PRE_CHAT_FORM_SETTINGS')"
        :is-loading="uiFlags.isUpdating"
      />
    </ChannelFormActions>
  </form>
</template>

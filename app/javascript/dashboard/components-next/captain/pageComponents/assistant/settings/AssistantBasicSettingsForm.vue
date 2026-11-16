<script setup>
import { reactive, computed, nextTick, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';

import Input from 'dashboard/components-next/input/Input.vue';
import Editor from 'dashboard/components-next/Editor/Editor.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import { useBusinessExamples } from 'dashboard/components-next/captain/assistant/useBusinessExamples';
import AssistantChatPreview from './AssistantChatPreview.vue';
import SettingsCard from './SettingsCard.vue';
import SettingsSaveBar from './SettingsSaveBar.vue';
import { useSettingsSave } from './useSettingsSave';
import SettingsSplit from './SettingsSplit.vue';

const props = defineProps({
  assistant: {
    type: Object,
    default: () => ({}),
  },
  // Async save so the form knows when the request has finished.
  deleteAvatar: { type: Function, required: true },
  save: {
    type: Function,
    required: true,
  },
});

const { t } = useI18n();
const examples = useBusinessExamples(computed(() => props.assistant.id));
const previewReply = computed(() =>
  examples.reply(props.assistant.config?.tone)
);

const DESCRIPTION_MAX_LENGTH = 500;

const state = reactive({
  name: '',
  description: '',
  productName: '',
  avatar: null,
  avatarUrl: '',
});

const validationRules = {
  name: { required, minLength: minLength(1) },
  description: { required, minLength: minLength(1) },
  productName: { required, minLength: minLength(1) },
};

const v$ = useVuelidate(validationRules, state);

const savedSnapshot = ref('');
const snapshot = () =>
  JSON.stringify([state.name, state.description, state.productName]);
const isDirty = computed(
  () => Boolean(state.avatar) || snapshot() !== savedSnapshot.value
);

const getErrorMessage = field => {
  return v$.value[field].$error ? v$.value[field].$errors[0].$message : '';
};

const formErrors = computed(() => ({
  name: getErrorMessage('name'),
  description: getErrorMessage('description'),
  productName: getErrorMessage('productName'),
}));

const updateStateFromAssistant = assistant => {
  const { config = {} } = assistant;
  state.name = assistant.name;
  state.description = assistant.description;
  state.avatarUrl = assistant.avatar_url || '';
  state.avatar = null;
  state.productName = config.product_name;
  savedSnapshot.value = snapshot();
};

const discard = () => {
  v$.value.$reset();
  updateStateFromAssistant(props.assistant);
};

const handleImageUpload = ({ file, url }) => {
  state.avatar = file;
  state.avatarUrl = url;
};

const deletingAvatar = ref(false);
const handleAvatarDelete = async () => {
  if (state.avatar) {
    state.avatar = null;
    state.avatarUrl = props.assistant.avatar_url || '';
    return;
  }
  deletingAvatar.value = true;
  try {
    await props.deleteAvatar();
    state.avatarUrl = props.assistant.avatar_url || '';
  } finally {
    deletingAvatar.value = false;
  }
};

const handleBasicInfoUpdate = async () => {
  const result = await v$.value.$validate();
  if (!result) return undefined;

  const payload = {
    name: state.name,
    description: state.description,
    config: {
      ...props.assistant.config,
      product_name: state.productName,
    },
  };

  if (state.avatar) {
    payload.avatar = state.avatar;
  }

  return props.save(payload);
};

watch(
  [
    () => props.assistant.id,
    () => props.assistant.name,
    () => props.assistant.description,
    () => props.assistant.config?.product_name,
    () => props.assistant.avatar_url,
  ],
  ([id]) => {
    if (id && !deletingAvatar.value) discard();
  },
  { immediate: true }
);

// A suggested summary fills the field; the owner still saves it with the save bar.
const setDescription = text => {
  state.description = text;
};
const {
  isSaving,
  isSaved,
  saveError,
  save: saveChanges,
} = useSettingsSave(isDirty, handleBasicInfoUpdate);
const profileFields = ref(null);
watch(isSaving, async saving => {
  if (saving || !v$.value.$error) return;
  await nextTick();
  profileFields.value
    ?.querySelector(
      'input[aria-invalid="true"], [aria-invalid="true"] [contenteditable="true"]'
    )
    ?.focus();
});
</script>

<template>
  <SettingsSplit>
    <SettingsCard
      :title="t('CAPTAIN.AGENT_UX.CONFIGURATION.CURRENT')"
      :description="
        assistant.config?.product_name
          ? t('CAPTAIN.AGENT_UX.CONFIGURATION.PROFILE.SUMMARY', {
              name: assistant.name,
              business: assistant.config.product_name,
            })
          : assistant.name
      "
    />
    <div ref="profileFields" :inert="isSaving || deletingAvatar">
      <SettingsCard
        :title="
          t('CAPTAIN.ASSISTANTS.SETTINGS.IDENTITY.TITLE', { name: state.name })
        "
        :description="
          t('CAPTAIN.ASSISTANTS.SETTINGS.IDENTITY.DESCRIPTION', {
            name: state.name,
          })
        "
      >
        <div class="flex flex-col gap-5 pt-4">
          <div class="flex flex-col gap-4 sm:flex-row sm:items-start">
            <div
              v-tooltip.bottom="t('CAPTAIN.ASSISTANTS.FORM.AVATAR.HELP_TEXT')"
              class="relative w-fit shrink-0 cursor-pointer"
            >
              <Avatar
                :src="state.avatarUrl"
                :name="state.name"
                :size="56"
                allow-upload
                icon-name="i-lucide-bot-message-square"
                rounded-full
                @upload="handleImageUpload"
                @delete="handleAvatarDelete"
              />
              <span
                class="absolute -bottom-0.5 -end-0.5 flex items-center justify-center size-5 rounded-full bg-n-solid-1 border border-n-weak text-n-slate-11 shadow-sm pointer-events-none"
                aria-hidden="true"
              >
                <span class="i-lucide-camera size-3" />
              </span>
            </div>
            <div class="grid flex-1 min-w-0 gap-4 sm:grid-cols-2">
              <Input
                id="agent-profile-name"
                v-model="state.name"
                :aria-invalid="Boolean(formErrors.name)"
                :label="t('CAPTAIN.ASSISTANTS.FORM.NAME.LABEL')"
                :placeholder="t('CAPTAIN.ASSISTANTS.FORM.NAME.PLACEHOLDER')"
                :message="
                  formErrors.name ||
                  t('CAPTAIN.ASSISTANTS.FORM.NAME.AI_BADGE_NOTE')
                "
                :message-type="formErrors.name ? 'error' : 'info'"
              />
              <Input
                id="agent-profile-business"
                v-model="state.productName"
                :aria-invalid="Boolean(formErrors.productName)"
                :label="t('CAPTAIN.ASSISTANTS.SETTINGS.IDENTITY.WORKS_FOR')"
                :placeholder="
                  t(
                    'CAPTAIN.ASSISTANTS.SETTINGS.IDENTITY.WORKS_FOR_PLACEHOLDER'
                  )
                "
                :message="formErrors.productName"
                :message-type="formErrors.productName ? 'error' : 'info'"
              />
            </div>
          </div>

          <Editor
            v-model="state.description"
            :aria-invalid="Boolean(formErrors.description)"
            :max-length="DESCRIPTION_MAX_LENGTH"
            :label="t('CAPTAIN.ASSISTANTS.SETTINGS.IDENTITY.ABOUT')"
            :placeholder="
              t('CAPTAIN.ASSISTANTS.SETTINGS.IDENTITY.ABOUT_PLACEHOLDER', {
                name: state.name,
              })
            "
            :message="formErrors.description"
            :message-type="formErrors.description ? 'error' : 'info'"
            class="z-0"
          />
          <p v-if="assistant.avatar_url" class="m-0 text-sm text-n-slate-11">
            {{ t('CAPTAIN.AGENT_UX.CONFIGURATION.PROFILE.AVATAR_REMOVAL') }}
          </p>
        </div>
      </SettingsCard>
    </div>

    <SettingsSaveBar
      :is-dirty="isDirty"
      :is-saving="isSaving || deletingAvatar"
      :is-saved="isSaved"
      :error="saveError"
      @save="saveChanges"
      @discard="discard"
    />

    <div :inert="isSaving || deletingAvatar">
      <slot
        :description="state.description"
        :description-max-length="DESCRIPTION_MAX_LENGTH"
        :set-description="setDescription"
      />
    </div>

    <template #preview>
      <AssistantChatPreview
        :name="state.name"
        :avatar-url="state.avatarUrl"
        :subtitle="
          state.productName
            ? `${t('CAPTAIN.ASSISTANTS.SETTINGS.PREVIEW.AI_AGENT')} · ${state.productName}`
            : t('CAPTAIN.ASSISTANTS.SETTINGS.PREVIEW.AI_AGENT')
        "
      >
        <p class="preview-bubble preview-bubble--agent">
          {{
            t('CAPTAIN.ASSISTANTS.SETTINGS.IDENTITY.PREVIEW_GREETING', {
              name: state.name,
            })
          }}
        </p>
        <p class="preview-bubble preview-bubble--customer">
          {{ examples.question.value }}
        </p>
        <p class="preview-bubble preview-bubble--agent">
          {{ previewReply }}
        </p>
      </AssistantChatPreview>
    </template>
  </SettingsSplit>
</template>

<script setup>
import { reactive, computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';

import Input from 'dashboard/components-next/input/Input.vue';
import Editor from 'dashboard/components-next/Editor/Editor.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import AssistantChatPreview from './AssistantChatPreview.vue';
import SettingsSaveBar from './SettingsSaveBar.vue';
import SettingsSplit from './SettingsSplit.vue';

const props = defineProps({
  assistant: {
    type: Object,
    default: () => ({}),
  },
  // Async save so the form knows when the request has finished.
  save: {
    type: Function,
    required: true,
  },
});

const emit = defineEmits(['deleteAvatar']);

const { t } = useI18n();

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

const isSaving = ref(false);
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

const handleAvatarDelete = () => {
  state.avatar = null;
  state.avatarUrl = '';
  emit('deleteAvatar');
};

const handleBasicInfoUpdate = async () => {
  const result = await v$.value.$validate();
  if (!result) return;

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

  isSaving.value = true;
  try {
    await props.save(payload);
  } finally {
    isSaving.value = false;
  }
};

watch(
  () => props.assistant,
  newAssistant => {
    if (newAssistant) updateStateFromAssistant(newAssistant);
  },
  { immediate: true }
);
</script>

<template>
  <SettingsSplit>
    <div class="flex items-center gap-4">
      <Avatar
        :src="state.avatarUrl"
        :name="state.name"
        :size="64"
        allow-upload
        icon-name="i-lucide-bot-message-square"
        rounded-full
        @upload="handleImageUpload"
        @delete="handleAvatarDelete"
      />
      <span class="text-sm text-n-slate-11">
        {{ t('CAPTAIN.ASSISTANTS.FORM.AVATAR.HELP_TEXT') }}
      </span>
    </div>

    <div class="grid gap-5 sm:grid-cols-2">
      <Input
        v-model="state.name"
        :label="t('CAPTAIN.ASSISTANTS.FORM.NAME.LABEL')"
        :placeholder="t('CAPTAIN.ASSISTANTS.FORM.NAME.PLACEHOLDER')"
        :message="
          formErrors.name || t('CAPTAIN.ASSISTANTS.FORM.NAME.AI_BADGE_NOTE')
        "
        :message-type="formErrors.name ? 'error' : 'info'"
      />

      <Input
        v-model="state.productName"
        :label="t('CAPTAIN.ASSISTANTS.SETTINGS.IDENTITY.WORKS_FOR')"
        :placeholder="
          t('CAPTAIN.ASSISTANTS.SETTINGS.IDENTITY.WORKS_FOR_PLACEHOLDER')
        "
        :message="formErrors.productName"
        :message-type="formErrors.productName ? 'error' : 'info'"
      />
    </div>

    <Editor
      v-model="state.description"
      :max-length="500"
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

    <SettingsSaveBar
      :is-dirty="isDirty"
      :is-saving="isSaving"
      @save="handleBasicInfoUpdate"
      @discard="discard"
    />

    <template #preview>
      <AssistantChatPreview :name="state.name" :avatar-url="state.avatarUrl" />
    </template>
  </SettingsSplit>
</template>

<script setup>
import { reactive, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Editor from 'dashboard/components-next/Editor/Editor.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

const props = defineProps({
  assistant: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['submit', 'deleteAvatar']);

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

  emit('submit', payload);
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
  <div class="flex flex-col gap-5">
    <div class="flex items-center gap-4">
      <Avatar
        :src="state.avatarUrl"
        :name="state.name"
        :size="68"
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

    <div>
      <Button
        :label="t('CAPTAIN.ASSISTANTS.SETTINGS.SAVE')"
        @click="handleBasicInfoUpdate"
      />
    </div>
  </div>
</template>

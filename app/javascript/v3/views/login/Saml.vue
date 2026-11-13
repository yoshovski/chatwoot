<script setup>
import { ref, nextTick, onMounted } from 'vue';
import { required, email } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

// components
import FormInput from '../../components/Form/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import AuthLayout from '../../components/AuthLayout/AuthLayout.vue';

const props = defineProps({
  authError: {
    type: String,
    default: '',
  },
  target: {
    type: String,
    default: 'web',
  },
});

const { t } = useI18n();

const credentials = ref({
  email: '',
});

const loginApi = ref({
  showLoading: false,
  hasErrored: false,
});

const handleAuthError = () => {
  if (!props.authError) {
    return;
  }

  const translatedMessage = t('LOGIN.SAML.API.ERROR_MESSAGE');
  useAlert(translatedMessage);
  loginApi.value.hasErrored = true;
};

const validations = {
  credentials: {
    email: {
      required,
      email,
    },
  },
};

const v$ = useVuelidate(validations, { credentials });

const csrfToken = ref('');

onMounted(async () => {
  csrfToken.value =
    document
      .querySelector('meta[name="csrf-token"]')
      ?.getAttribute('content') || '';

  await nextTick(handleAuthError);
});
</script>

<template>
  <AuthLayout
    :title="t('LOGIN.SAML.TITLE')"
    :description="t('LOGIN.SAML.SUBTITLE')"
  >
    <form
      class="space-y-5"
      :class="{ 'animate-wiggle': loginApi.hasErrored }"
      method="POST"
      action="/api/v1/auth/saml_login"
    >
      <FormInput
        v-model="credentials.email"
        name="email"
        type="email"
        autocomplete="email"
        required
        :label="t('LOGIN.SAML.WORK_EMAIL.LABEL')"
        :placeholder="t('LOGIN.SAML.WORK_EMAIL.PLACEHOLDER')"
        :has-error="v$.credentials.email.$error"
        @input="v$.credentials.email.$touch"
      />
      <input
        type="hidden"
        class="h-0"
        name="authenticity_token"
        :value="csrfToken"
      />
      <input type="hidden" class="h-0" name="target" :value="target" />
      <NextButton
        lg
        type="submit"
        class="w-full"
        :label="t('LOGIN.SAML.SUBMIT')"
        :disabled="loginApi.showLoading"
        :is-loading="loginApi.showLoading"
      />
    </form>
    <p class="mt-6 mb-0 text-sm text-n-slate-11">
      <router-link to="/app/login" class="text-link">
        {{ t('LOGIN.SAML.BACK_TO_LOGIN') }}
      </router-link>
    </p>
  </AuthLayout>
</template>

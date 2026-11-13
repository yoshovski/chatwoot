<script>
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required, minLength, email } from '@vuelidate/validators';
import { useBranding } from 'shared/composables/useBranding';
import FormInput from '../../../../components/Form/Input.vue';
import { resetPassword } from '../../../../api/auth';
import NextButton from 'dashboard/components-next/button/Button.vue';
import AuthLayout from '../../../../components/AuthLayout/AuthLayout.vue';

export default {
  components: { FormInput, NextButton, AuthLayout },
  setup() {
    const { replaceInstallationName } = useBranding();
    return { v$: useVuelidate(), replaceInstallationName };
  },
  data() {
    return {
      credentials: { email: '' },
      resetPassword: {
        message: '',
        showLoading: false,
      },
      error: '',
    };
  },
  validations() {
    return {
      credentials: {
        email: {
          required,
          email,
          minLength: minLength(4),
        },
      },
    };
  },
  methods: {
    showAlertMessage(message) {
      // Reset loading, current selected agent
      this.resetPassword.showLoading = false;
      useAlert(message);
    },
    submit() {
      this.resetPassword.showLoading = true;
      resetPassword(this.credentials)
        .then(res => {
          let successMessage = this.$t('RESET_PASSWORD.API.SUCCESS_MESSAGE');
          if (res.data && res.data.message) {
            successMessage = res.data.message;
          }
          this.showAlertMessage(successMessage);
        })
        .catch(error => {
          let errorMessage = this.$t('RESET_PASSWORD.API.ERROR_MESSAGE');
          if (error?.response?.data?.message) {
            errorMessage = error.response.data.message;
          }
          this.showAlertMessage(errorMessage);
        });
    },
  },
};
</script>

<template>
  <AuthLayout
    :title="$t('RESET_PASSWORD.TITLE')"
    :description="replaceInstallationName($t('RESET_PASSWORD.DESCRIPTION'))"
  >
    <form class="space-y-5" @submit.prevent="submit">
      <FormInput
        v-model="credentials.email"
        name="email_address"
        type="email"
        autocomplete="email"
        :label="$t('LOGIN.EMAIL.LABEL')"
        :has-error="v$.credentials.email.$error"
        :error-message="$t('RESET_PASSWORD.EMAIL.ERROR')"
        :placeholder="$t('RESET_PASSWORD.EMAIL.PLACEHOLDER')"
        @input="v$.credentials.email.$touch"
      />
      <NextButton
        lg
        type="submit"
        data-testid="submit_button"
        class="w-full"
        :label="$t('RESET_PASSWORD.SUBMIT')"
        :disabled="v$.credentials.email.$invalid || resetPassword.showLoading"
        :is-loading="resetPassword.showLoading"
      />
    </form>
    <p class="mt-6 mb-0 text-sm text-n-slate-11">
      <router-link to="/app/login" class="text-link">
        {{ $t('RESET_PASSWORD.GO_BACK_TO_LOGIN') }}
      </router-link>
    </p>
  </AuthLayout>
</template>

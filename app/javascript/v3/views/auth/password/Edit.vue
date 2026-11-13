<script>
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import FormInput from '../../../components/Form/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import AuthLayout from '../../../components/AuthLayout/AuthLayout.vue';
import { DEFAULT_REDIRECT_URL } from 'dashboard/constants/globals';
import { setNewPassword } from '../../../api/auth';

export default {
  components: {
    AuthLayout,
    FormInput,
    NextButton,
  },
  props: {
    resetPasswordToken: { type: String, default: '' },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      // We need to initialize the component with any
      // properties that will be used in it
      credentials: {
        confirmPassword: '',
        password: '',
      },
      newPasswordAPI: {
        message: '',
        showLoading: false,
      },
      error: '',
    };
  },
  mounted() {
    // If url opened without token
    // redirect to login
    if (!this.resetPasswordToken) {
      window.location = DEFAULT_REDIRECT_URL;
    }
  },
  validations: {
    credentials: {
      password: {
        required,
        minLength: minLength(6),
      },
      confirmPassword: {
        required,
        minLength: minLength(6),
        isEqPassword(value) {
          if (value !== this.credentials.password) {
            return false;
          }
          return true;
        },
      },
    },
  },
  methods: {
    showAlertMessage(message) {
      // Reset loading, current selected agent
      this.newPasswordAPI.showLoading = false;
      useAlert(message);
    },
    submitForm() {
      this.newPasswordAPI.showLoading = true;
      const credentials = {
        confirmPassword: this.credentials.confirmPassword,
        password: this.credentials.password,
        resetPasswordToken: this.resetPasswordToken,
      };
      setNewPassword(credentials)
        .then(() => {
          window.location = DEFAULT_REDIRECT_URL;
        })
        .catch(error => {
          this.showAlertMessage(
            error?.message || this.$t('SET_NEW_PASSWORD.API.ERROR_MESSAGE')
          );
        });
    },
  },
};
</script>

<template>
  <AuthLayout :title="$t('SET_NEW_PASSWORD.TITLE')">
    <form class="space-y-5" @submit.prevent="submitForm">
      <FormInput
        v-model="credentials.password"
        name="password"
        type="password"
        autocomplete="new-password"
        :label="$t('SET_NEW_PASSWORD.PASSWORD.LABEL')"
        :has-error="v$.credentials.password.$error"
        :error-message="$t('SET_NEW_PASSWORD.PASSWORD.ERROR')"
        :placeholder="$t('SET_NEW_PASSWORD.PASSWORD.PLACEHOLDER')"
        @blur="v$.credentials.password.$touch"
      />
      <FormInput
        v-model="credentials.confirmPassword"
        name="confirm_password"
        type="password"
        autocomplete="new-password"
        :label="$t('SET_NEW_PASSWORD.CONFIRM_PASSWORD.LABEL')"
        :has-error="v$.credentials.confirmPassword.$error"
        :error-message="$t('SET_NEW_PASSWORD.CONFIRM_PASSWORD.ERROR')"
        :placeholder="$t('SET_NEW_PASSWORD.CONFIRM_PASSWORD.PLACEHOLDER')"
        @blur="v$.credentials.confirmPassword.$touch"
      />
      <NextButton
        lg
        type="submit"
        data-testid="submit_button"
        class="w-full"
        :label="$t('SET_NEW_PASSWORD.SUBMIT')"
        :disabled="
          v$.credentials.password.$invalid ||
          v$.credentials.confirmPassword.$invalid ||
          newPasswordAPI.showLoading
        "
        :is-loading="newPasswordAPI.showLoading"
      />
    </form>
  </AuthLayout>
</template>

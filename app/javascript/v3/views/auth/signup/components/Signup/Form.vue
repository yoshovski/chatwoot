<script setup>
import { ref, computed, reactive, watch } from 'vue';
import DOMPurify from 'dompurify';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, email } from '@vuelidate/validators';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import CaptchaWidget from '../../../../../components/Captcha/CaptchaWidget.vue';
import FormInput from '../../../../../components/Form/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import PasswordRequirements from './PasswordRequirements.vue';
import { isValidPassword } from 'shared/helpers/Validators';
import GoogleOAuthButton from '../../../../../components/GoogleOauth/Button.vue';
import SimpleDivider from '../../../../../components/Divider/SimpleDivider.vue';
import { register } from '../../../../../api/auth';
import * as CompanyEmailValidator from 'company-email-validator';

const MIN_PASSWORD_LENGTH = 6;
const WEBSITE_PATTERN = /^(https?:\/\/)?([a-z0-9-]+\.)+[a-z]{2,}(\/\S*)?$/i;
const store = useStore();
const { t } = useI18n();

// Codes the sign-up API returns for an email it refuses; anything else is shown as a toast.
const EMAIL_API_ERRORS = {
  email_taken: () => t('REGISTER.EMAIL.TAKEN'),
  email_blocked: () => t('REGISTER.EMAIL.BLOCKED'),
  email_disposable: () => t('REGISTER.EMAIL.DISPOSABLE'),
  email_invalid: () => t('REGISTER.EMAIL.ERROR'),
};
const router = useRouter();

const captcha = ref(null);
const isPasswordFocused = ref(false);
const isSignupInProgress = ref(false);
const emailErrorCode = ref('');

const credentials = reactive({
  email: '',
  password: '',
  website: '',
  captchaResponse: '',
});

const rules = {
  credentials: {
    email: {
      required,
      email,
      businessEmailValidator(value) {
        return CompanyEmailValidator.isCompanyEmail(value);
      },
    },
    password: {
      required,
      isValidPassword,
      minLength: minLength(MIN_PASSWORD_LENGTH),
    },
    website: {
      required,
      validWebsite: value => WEBSITE_PATTERN.test(value.trim()),
    },
  },
};

const v$ = useVuelidate(rules, { credentials });

watch(
  () => credentials.email,
  () => {
    emailErrorCode.value = '';
  }
);

const emailError = computed(() => {
  if (emailErrorCode.value) return EMAIL_API_ERRORS[emailErrorCode.value]();
  const field = v$.value.credentials.email;
  if (!field.$error) return '';
  if (!field.required.$invalid && !field.email.$invalid) {
    return t('REGISTER.EMAIL.PERSONAL');
  }
  return t('REGISTER.EMAIL.ERROR');
});

const globalConfig = computed(() => store.getters['globalConfig/get']);

const termsLink = computed(() =>
  t('REGISTER.TERMS_ACCEPT')
    .replace('https://www.chatwoot.com/terms', globalConfig.value.termsURL)
    .replace(
      'https://www.chatwoot.com/privacy-policy',
      globalConfig.value.privacyURL
    )
);

const sanitizedTermsLink = computed(() => DOMPurify.sanitize(termsLink.value));

const allowedLoginMethods = computed(
  () => window.chatwootConfig.allowedLoginMethods || ['email']
);

const showGoogleOAuth = computed(
  () =>
    allowedLoginMethods.value.includes('google_oauth') &&
    Boolean(window.chatwootConfig.googleOAuthClientId)
);

const performRegistration = async () => {
  isSignupInProgress.value = true;
  try {
    await register({ ...credentials, website: credentials.website.trim() });
    router.push({
      name: 'auth_verify_email',
      state: { email: credentials.email },
    });
  } catch (error) {
    if (globalConfig.value.captchaProvider) {
      captcha.value.reset();
      credentials.captchaResponse = '';
    }
    if (EMAIL_API_ERRORS[error.code]) {
      emailErrorCode.value = error.code;
    } else {
      useAlert(error?.message || t('REGISTER.API.ERROR_MESSAGE'));
    }
  } finally {
    isSignupInProgress.value = false;
  }
};

const submit = () => {
  if (isSignupInProgress.value) return;
  v$.value.$touch();
  if (v$.value.$invalid) return;
  isSignupInProgress.value = true;
  if (globalConfig.value.captchaProvider) {
    captcha.value.execute();
  } else {
    performRegistration();
  }
};

const onRecaptchaVerified = token => {
  credentials.captchaResponse = token;
  performRegistration();
};

const onCaptchaError = () => {
  isSignupInProgress.value = false;
  credentials.captchaResponse = '';
  captcha.value.reset();
};
</script>

<template>
  <div class="flex-1">
    <template v-if="showGoogleOAuth">
      <GoogleOAuthButton>
        {{ $t('REGISTER.OAUTH.GOOGLE_SIGNUP') }}
      </GoogleOAuthButton>
      <SimpleDivider
        :label="$t('COMMON.OR')"
        bg="bg-n-solid-1"
        class="uppercase"
      />
    </template>
    <form class="space-y-3" novalidate @submit.prevent="submit">
      <div>
        <FormInput
          v-model="credentials.email"
          type="email"
          name="email_address"
          autocomplete="email"
          :label="$t('REGISTER.EMAIL.LABEL')"
          :placeholder="$t('REGISTER.EMAIL.PLACEHOLDER')"
          :has-error="Boolean(emailError)"
          :error-message="emailError"
          @blur="v$.credentials.email.$touch"
        />
        <router-link
          v-if="emailErrorCode === 'email_taken'"
          to="/app/login"
          data-testid="log_in_instead"
          class="mt-1 inline-block text-sm text-link"
        >
          {{ $t('REGISTER.EMAIL.LOG_IN_INSTEAD') }}
        </router-link>
      </div>
      <div class="relative">
        <FormInput
          v-model="credentials.password"
          type="password"
          name="password"
          autocomplete="new-password"
          :label="$t('LOGIN.PASSWORD.LABEL')"
          :placeholder="$t('SET_NEW_PASSWORD.PASSWORD.PLACEHOLDER')"
          :has-error="v$.credentials.password.$error"
          :error-message="$t('REGISTER.PASSWORD.IS_INVALID_PASSWORD')"
          @focus="isPasswordFocused = true"
          @blur="
            isPasswordFocused = false;
            v$.credentials.password.$touch();
          "
        />
        <Transition
          enter-active-class="transition duration-200 ease-out origin-left"
          enter-from-class="opacity-0 scale-90 translate-x-1"
          enter-to-class="opacity-100 scale-100 translate-x-0"
          leave-active-class="transition duration-150 ease-in origin-left"
          leave-from-class="opacity-100 scale-100 translate-x-0"
          leave-to-class="opacity-0 scale-90 translate-x-1"
        >
          <PasswordRequirements
            v-if="isPasswordFocused"
            :password="credentials.password"
          />
        </Transition>
      </div>
      <FormInput
        v-model="credentials.website"
        type="text"
        name="website"
        inputmode="url"
        autocomplete="url"
        :label="$t('REGISTER.WEBSITE.LABEL')"
        :placeholder="$t('REGISTER.WEBSITE.PLACEHOLDER')"
        :has-error="v$.credentials.website.$error"
        :error-message="$t('REGISTER.WEBSITE.ERROR')"
        @blur="v$.credentials.website.$touch"
      />
      <CaptchaWidget
        v-if="globalConfig.captchaProvider"
        ref="captcha"
        :provider="globalConfig.captchaProvider"
        :site-key="globalConfig.captchaSiteKey"
        @verify="onRecaptchaVerified"
        @error="onCaptchaError"
      />
      <NextButton
        lg
        type="submit"
        data-testid="submit_button"
        class="w-full font-medium"
        :label="$t('REGISTER.SUBMIT')"
        :disabled="isSignupInProgress"
        :is-loading="isSignupInProgress"
      />
    </form>
    <p
      class="text-sm mt-5 mb-0 text-n-slate-11 [&>a]:text-n-blue-11 [&>a]:font-medium [&>a]:hover:text-n-blue-10"
      v-html="sanitizedTermsLink"
    />
  </div>
</template>

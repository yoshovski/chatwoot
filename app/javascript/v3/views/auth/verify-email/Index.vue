<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import CaptchaWidget from '../../../components/Captcha/CaptchaWidget.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import AuthLayout from '../../../components/AuthLayout/AuthLayout.vue';
import { resendConfirmation } from '../../../api/auth';

const props = defineProps({
  email: {
    type: String,
    default: '',
  },
});

const { t } = useI18n();
const router = useRouter();
const store = useStore();

if (!props.email) {
  router.push({ name: 'login' });
}

const globalConfig = computed(() => store.getters['globalConfig/get']);
const isResendingEmail = ref(false);
const captcha = ref(null);
let captchaToken = '';

const performResend = async () => {
  isResendingEmail.value = true;
  try {
    await resendConfirmation({
      email: props.email,
      captchaResponse: captchaToken,
    });
    useAlert(t('REGISTER.VERIFY_EMAIL.RESEND_SUCCESS'));
  } catch {
    useAlert(t('REGISTER.VERIFY_EMAIL.RESEND_ERROR'));
  } finally {
    isResendingEmail.value = false;
    captchaToken = '';
    if (globalConfig.value.captchaProvider) {
      captcha.value.reset();
    }
  }
};

const handleResendEmail = () => {
  if (isResendingEmail.value) return;
  if (globalConfig.value.captchaProvider) {
    captcha.value.execute();
  } else {
    performResend();
  }
};

const onCaptchaVerified = token => {
  captchaToken = token;
  performResend();
};

const onCaptchaError = () => {
  isResendingEmail.value = false;
  captchaToken = '';
  captcha.value.reset();
};
</script>

<template>
  <AuthLayout
    :title="$t('REGISTER.VERIFY_EMAIL.TITLE')"
    :description="$t('REGISTER.VERIFY_EMAIL.DESCRIPTION', { email })"
  >
    <div class="space-y-4">
      <CaptchaWidget
        v-if="globalConfig.captchaProvider"
        ref="captcha"
        :provider="globalConfig.captchaProvider"
        :site-key="globalConfig.captchaSiteKey"
        @verify="onCaptchaVerified"
        @error="onCaptchaError"
      />
      <NextButton
        lg
        type="button"
        data-testid="resend_email_button"
        class="w-full"
        :label="$t('REGISTER.VERIFY_EMAIL.RESEND')"
        :is-loading="isResendingEmail"
        @click="handleResendEmail"
      />
    </div>
    <p class="mt-5 mb-0 text-sm text-n-slate-11">
      {{ $t('REGISTER.VERIFY_EMAIL.SPAM_HINT') }}
    </p>
    <p class="mt-3 mb-0 text-sm text-n-slate-11">
      {{ $t('REGISTER.VERIFY_EMAIL.WRONG_ADDRESS') }}
      <router-link
        to="/app/auth/signup"
        data-testid="sign_up_again"
        class="text-link"
      >
        {{ $t('REGISTER.VERIFY_EMAIL.SIGN_UP_AGAIN') }}
      </router-link>
    </p>
  </AuthLayout>
</template>
